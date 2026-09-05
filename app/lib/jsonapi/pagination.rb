# frozen_string_literal: true

require "uri"

module Jsonapi
  # offset 페이지네이션의 scope 적용과 링크 조립.
  #
  # `next`는 probe(요청 크기 +1행을 읽어 유무를 판정)로 정해지고, `last`는
  # `page[totals]=true`가 실행한 COUNT가 있을 때만 나온다. 실제 COUNT 실행과
  # probe 조회는 `QueryParser`가 하고, 여기는 그 결과로 scope를 자르고
  # 링크를 조립하는 순수 함수만 담는다.
  module Pagination
    MAX_PAGE_SIZE = 100
    MAX_SQL_INTEGER = (2**63) - 1

    module_function

    # `limit`은 probe가 요청 크기보다 한 행 더 읽을 때만 `page_size`와 달라진다.
    # offset은 항상 실제 페이지 크기(`page_size`) 기준이어야 한다 — limit을 offset
    # 계산에도 함께 쓰면 2페이지부터 창이 그만큼씩 밀린다.
    def apply(scope, page_number:, page_size:, limit: page_size)
      scope.offset((page_number - 1) * page_size).limit(limit)
    end

    # `next`는 probe 행의 유무로 판정한다. `last`는 총 개수를 알아야 만들 수 있으므로
    # `page[totals]=true`로 COUNT를 실행한 요청에서만 나온다 — 그 외에는 nil이다.
    #
    # `totals`는 `total_count`(nil일 수도, 0일 수도 있는 COUNT 결과)가 아니라 요청 자체가
    # totals를 요청했는지를 나타낸다 — 둘을 섞으면 빈 컬렉션에 대한 totals 요청
    # (total_count == 0)에서 링크의 page[totals]=true가 빠지는 잘못이 생긴다.
    def links(request:, raw_pairs:, page_number:, page_size:, has_more:, total_count:, totals:)
      last_page = total_count && [ 1, (total_count + page_size - 1) / page_size ].max
      {
        "self" => page_link(request, raw_pairs, page_number, page_size, totals: totals),
        "first" => page_link(request, raw_pairs, 1, page_size, totals: totals),
        "prev" => page_number > 1 ? page_link(request, raw_pairs, page_number - 1, page_size, totals: totals) : nil,
        "next" => has_more ? page_link(request, raw_pairs, page_number + 1, page_size, totals: totals) : nil,
        "last" => last_page ? page_link(request, raw_pairs, last_page, page_size, totals: totals) : nil
      }
    end

    # 순서는 정본과 맞춘다: 보존된 비-page 파라미터 → page[totals] → page[number] → page[size].
    def page_link(request, raw_pairs, number, size, totals:)
      preserved = raw_pairs.reject { |parameter, _| parameter == "page" || parameter.start_with?("page[") }
      totals_pair = totals ? [ [ "page[totals]", "true" ] ] : []
      query = URI.encode_www_form(
        [ *preserved, *totals_pair, [ "page[number]", number.to_s ], [ "page[size]", size.to_s ] ]
      )
      "#{request.path}?#{query}"
    end

    # 커서 링크는 페이지 번호가 아니라 경계 행의 정렬 값으로 만든다. 마지막 행이
    # 다음 페이지의 시작이고 첫 행이 이전 페이지의 끝이다.
    #
    # `prev`/`next`의 발행 조건이 방향에 따라 뒤바뀐다. 앞으로 읽는 중이면 "다음"은
    # probe가 알려주고 "이전"은 우리가 어디선가 왔다는 사실이 알려준다. 뒤로 읽는
    # 중이면 정반대다. 빈 커서(`page[after]=`)로 시작한 요청은 컬렉션의 처음이므로
    # `prev`가 없다 — offset 모드 1페이지가 `prev`를 내지 않는 것과 같다.
    def cursor_links(request:, raw_pairs:, page_size:, totals:, records:, terms:,
                     attributes:, has_more:, before:, raw_cursor:)
      preserved = raw_pairs.reject { |parameter, _| parameter == "page" || parameter.start_with?("page[") }
      signature = Cursor.signature(terms)
      positioned = !raw_cursor.empty?
      emit_next = before ? positioned : has_more
      emit_prev = before ? has_more : positioned

      # "prev"는 언제나 page[before]로, "next"는 언제나 page[after]로 나간다(요청의
      # 방향과 무관하다) — 왕복 불가 값이라 커서를 못 만들 때 그 링크의 파라미터
      # 이름을 그대로 오류에 싣는다.
      previous_cursor =
        records.empty? ? nil : boundary_cursor(signature, terms, attributes, records.first, "page[before]")
      following_cursor =
        records.empty? ? nil : boundary_cursor(signature, terms, attributes, records.last, "page[after]")

      {
        "self" => cursor_link(request, preserved, page_size, totals,
                              before ? "page[before]" : "page[after]", raw_cursor),
        "first" => cursor_link(request, preserved, page_size, totals, "page[after]", ""),
        "prev" => emit_prev && previous_cursor ?
          cursor_link(request, preserved, page_size, totals, "page[before]", previous_cursor) : nil,
        "next" => emit_next && following_cursor ?
          cursor_link(request, preserved, page_size, totals, "page[after]", following_cursor) : nil,
        # 빈 문자열이 컬렉션의 끝을 가리키므로 총 개수를 몰라도 `last`를 만들 수 있다.
        "last" => cursor_link(request, preserved, page_size, totals, "page[before]", "")
      }
    end

    def boundary_cursor(signature, terms, attributes, record, parameter)
      values = terms.map do |term|
        value = record.public_send(attributes.fetch(term.name))
        raise Cursor.invalid_cursor(parameter) unless Cursor.encodable?(value)

        Cursor.serialize(value)
      end
      Cursor.encode(signature, values)
    end

    def cursor_link(request, preserved, page_size, totals, parameter, value)
      totals_pair = totals ? [ [ "page[totals]", "true" ] ] : []
      pairs = [ *preserved, *totals_pair, [ parameter, value ], [ "page[size]", page_size.to_s ] ]
      "#{request.path}?#{URI.encode_www_form(pairs)}"
    end
  end
end
