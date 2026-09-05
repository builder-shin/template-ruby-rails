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
  end
end
