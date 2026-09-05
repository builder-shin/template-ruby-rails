# frozen_string_literal: true

require "uri"

module Jsonapi
  # offset 페이지네이션의 scope 적용과 링크 조립.
  #
  # Task 3이 여기에 probe(요청 크기 +1행을 읽어 `next` 유무를 판정)를 얹는다.
  # 지금은 `QueryParser`에서 그대로 옮겨 온 로직뿐이다.
  module Pagination
    DEFAULT_PAGE_SIZE = 20
    MAX_PAGE_SIZE = 100
    MAX_SQL_INTEGER = (2**63) - 1

    module_function

    def apply(scope, page_number:, page_size:)
      scope.offset((page_number - 1) * page_size).limit(page_size)
    end

    def links(request:, raw_pairs:, page_number:, page_size:, total_count:)
      last_page = [ 1, (total_count + page_size - 1) / page_size ].max
      {
        "self" => page_link(request, raw_pairs, page_number, page_size),
        "first" => page_link(request, raw_pairs, 1, page_size),
        "prev" => page_number > 1 ? page_link(request, raw_pairs, page_number - 1, page_size) : nil,
        "next" => page_number < last_page ? page_link(request, raw_pairs, page_number + 1, page_size) : nil,
        "last" => page_link(request, raw_pairs, last_page, page_size)
      }
    end

    def page_link(request, raw_pairs, number, size)
      preserved = raw_pairs.reject { |parameter, _| parameter == "page" || parameter.start_with?("page[") }
      query = URI.encode_www_form(
        [ *preserved, [ "page[number]", number.to_s ], [ "page[size]", size.to_s ] ]
      )
      "#{request.path}?#{query}"
    end
  end
end
