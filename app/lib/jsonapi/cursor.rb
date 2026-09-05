# frozen_string_literal: true

require "base64"
require "json"

module Jsonapi
  # keyset 커서의 인코딩·디코딩과 비교 술어.
  #
  # 커서는 유효 정렬의 컬럼 값들을 담은 opaque 문자열이다. 서명(정렬의 이름과
  # 방향을 이어붙인 문자열)을 함께 담아, 정렬이 달라진 커서를 되돌려받으면
  # 거부한다 — 그러지 않으면 클라이언트가 다른 정렬의 위치로 페이지를 자른다.
  module Cursor
    module_function

    def signature(terms)
      terms.map { |term| "#{term.name}:#{term.descending ? 'desc' : 'asc'}" }.join(",")
    end

    def encode(signature, values)
      Base64.urlsafe_encode64(JSON.generate({ "s" => signature, "v" => values }), padding: false)
    end

    def decode(raw, expected_signature)
      payload = JSON.parse(Base64.urlsafe_decode64(raw))
      raise invalid_cursor unless payload.is_a?(Hash)
      raise invalid_cursor unless payload["s"] == expected_signature

      values = payload["v"]
      raise invalid_cursor unless values.is_a?(Array)
      raise invalid_cursor unless values.length == expected_signature.split(",").length

      values
    rescue ArgumentError, JSON::ParserError
      raise invalid_cursor
    end

    # 커서 값을 문자열로 왕복시킬 수 있는지 본다. 왕복시킬 수 없는 타입이 정렬에
    # 있으면 `next` 링크를 아예 발행할 수 없으므로, 첫 페이지 다음으로 넘어갈
    # 방법이 없는 응답이 나온다 — nullable 거부와 이유가 다르다.
    def encodable?(value)
      case value
      when String, Integer, TrueClass, FalseClass, NilClass then true
      when Time, DateTime, Date then true
      else false
      end
    end

    # 값은 전부 문자열로 담는다. 정본과 NestJS가 그렇게 하고, 무엇보다 JSON 왕복에서
    # 타입이 살아 돌아오는 것에 기대지 않게 된다 — 나중에 BigDecimal 같은 컬럼으로
    # 정렬을 열면 `JSON.generate`가 무엇을 뱉을지가 새 변수가 된다. PostgreSQL은
    # 비교 자리의 문자열 리터럴을 컬럼 타입으로 캐스팅하므로 술어는 그대로 동작한다.
    def serialize(value)
      case value
      when Time, DateTime then value.utc.iso8601(6)
      when Date then value.iso8601
      when true then "true"
      when false then "false"
      else value.to_s
      end
    end

    # `(a, b) > (x, y)`를 방향별로 펼친다. Arel에 행 비교가 없으므로 사전식으로
    # 전개한다 — 첫 키가 크거나, 같으면서 둘째 키가 크거나, ...
    #
    # 순수 OR는 sargable하지 않다 — 플래너가 인덱스 스캔의 시작점을 잡지 못해 커서
    # 앞의 행을 전부 읽고 버린다. 커서 모드가 없애려던 deep-OFFSET 비용 그대로다.
    # 선두 정렬 컬럼에 비엄격 경계를 AND로 붙이면 Index Cond가 생긴다. 모든 disjunct가
    # 이미 그 경계를 함의하므로(첫 항은 선두 컬럼에 엄격 비교, 나머지는 등호로 고정)
    # 결과 집합은 달라지지 않는다.
    def keyset_predicate(table, terms, attributes, values, before:)
      comparisons = terms.each_with_index.map do |term, index|
        equals = terms.first(index).each_with_index.map do |prior, prior_index|
          table[attributes.fetch(prior.name)].eq(values[prior_index])
        end
        strict = strict_comparison(table[attributes.fetch(term.name)], term, values[index], before: before)
        equals.reduce(strict) { |combined, equality| equality.and(combined) }
      end

      disjunction = comparisons.reduce { |combined, comparison| combined.or(comparison) }

      leading = terms.first
      leading_column = table[attributes.fetch(leading.name)]
      leading_bound =
        if leading.descending != before
          leading_column.lteq(values.first)
        else
          leading_column.gteq(values.first)
        end

      leading_bound.and(disjunction)
    end

    def strict_comparison(column, term, value, before:)
      descending = term.descending
      descending = !descending if before
      descending ? column.lt(value) : column.gt(value)
    end

    def invalid_cursor
      JsonApiError.new(status: 400, code: "INVALID_PAGE", source: { parameter: "page[after]" })
    end
  end
end
