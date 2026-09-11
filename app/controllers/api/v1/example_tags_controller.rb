# frozen_string_literal: true

module Api
  module V1
    # 라벨 자원. 읽기 전용이다.
    #
    # 라벨이 서버가 관리하는 참조 데이터라는 것, 쓰기 라우트를 열지 않는 이유,
    # 이 자원이 존재하는 이유는 `ExampleCategoriesController`와 같다.
    #
    # URL 경로는 `/api/v1/tags`이고 JSON:API type은 `exampleTags`다.
    class ExampleTagsController < ApiController
      def allowed_includes
        []
      end

      private

      def serializer_class
        ExampleTagSerializer
      end

      def jsonapi_resource_type
        "exampleTags"
      end

      # 기본 정렬이 `name ASC`인 것도 `includes`가 비어 있는 것도
      # `ExampleCategoriesController`와 같은 이유다.
      #
      # **인덱스 판단 — 만들지 않는다.** 근거는 `ExampleCategoriesController`와
      # 같다. `name`의 UNIQUE 인덱스가 `name` 순서를 주지만 `ORDER BY name, id`
      # 계획에는 incremental sort가 남는다 — 그럼에도 만들지 않는 이유는 `name`이
      # 유니크해서 동점 그룹이 항상 1이고 라벨 수가 적다는 것이다.
      def query_contract
        {
          filters: {
            "name" => { attribute: :name, type: :string, operators: %w[exact contains] }
          },
          sorts: {
            "name" => { attribute: :name, nullable: false },
            "createdAt" => { attribute: :created_at, nullable: false }
          },
          includes: [],
          default_sort: [ { field: "name", direction: :asc } ],
          tie_breaker: { field: "id", direction: :asc },
          default_page_size: 20
        }
      end

      def jsonapi_query_mode
        # show는 :none이 아니라 :include_only다 — 이유는 ExampleCategoriesController와
        # 같다.
        { "index" => :collection, "show" => :include_only }.fetch(action_name, :none)
      end

      def allowed_relationships
        {}
      end

      def normalized_resource_id(value)
        Jsonapi::ScalarGrammar.uuid(value.to_s)
      rescue ArgumentError
        raise JsonApiError.new(status: 404, code: "RESOURCE_NOT_FOUND")
      end
    end
  end
end
