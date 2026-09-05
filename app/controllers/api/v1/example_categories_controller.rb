# frozen_string_literal: true

module Api
  module V1
    # 분류 자원. 읽기 전용이다.
    #
    # 분류는 서버가 관리하는 참조 데이터다. 쓰기 라우트를 `config/routes.rb`에
    # 선언하지 않는 것이 Rails에서 "읽기 전용"의 전부다 — 라우트가 없으면
    # CrudActions가 물려준 write 액션은 도달할 수 없는 죽은 메서드다.
    #
    # 이 자원이 존재하는 이유는 관계 선택기다. 분류는 Example의 관계로만
    # 노출되어 있어서, 폼이 고를 목록을 가져올 곳이 없었다. `?include=`로 긁는
    # 방식은 불완전하다 — 어떤 Example에도 붙지 않은 분류는 영원히 나타나지 않는다.
    #
    # URL 경로는 `/api/v1/categories`이고 JSON:API type은 `exampleCategories`다.
    # 둘이 다른 것은 의도된 결정이다.
    #
    # `skip_before_action :set_current_user`는 읽기가 공개이기 때문이다. 이 줄은
    # 인증 이식(C2)이 그 콜백 자체를 없앨 때 함께 지워야 한다 — skip_before_action은
    # 없는 콜백을 건너뛰려 하면 ArgumentError를 낸다.
    class ExampleCategoriesController < ApiController
      RESOURCE_UUID = /\A[0-9a-f]{8}(?:-[0-9a-f]{4}){3}-[0-9a-f]{12}\z/i
      private_constant :RESOURCE_UUID

      skip_before_action :set_current_user

      def allowed_includes
        []
      end

      private

      def serializer_class
        ExampleCategorySerializer
      end

      def jsonapi_resource_type
        "exampleCategories"
      end

      # 기본 정렬이 `name ASC`인 것은 의도된 것이다. 선택기는 알파벳순이 맞고,
      # Example의 기본 정렬(`createdAt DESC`)과 다른 것은 참조 데이터를 최신순으로
      # 고르지 않기 때문이다.
      #
      # `includes`가 비어 있는 것도 의도된 것이다. `examples` 역참조를 열면
      # Example → category → examples → … 로 순환이 생긴다.
      #
      # **인덱스 판단 — 만들지 않는다.** 근거가 "기존 인덱스로 커버된다"가
      # **아니다.** `name`의 UNIQUE 인덱스가 `name` 순서를 주지만, PostgreSQL은
      # 유니크 제약을 근거로 뒤따르는 정렬 키를 지우지 않으므로 `ORDER BY name, id`
      # 계획에는 incremental sort가 남는다.
      #
      # 그럼에도 `(name, id)` 인덱스를 만들지 않는 이유는 둘이다. `name`이
      # 유니크해서 동점 그룹의 크기가 항상 1이라 그 정렬 단계가 실질적으로 하는
      # 일이 없고, 참조 테이블의 행 수가 작다(분류·라벨 각각 수십 개 규모).
      # `createdAt`은 유니크하지 않으므로 첫 번째 이유는 적용되지 않는다 — 같은
      # 트랜잭션에서 커밋된 행은 `now()` 값을 공유해 동점 그룹이 테이블 전체가
      # 될 수 있다. 그럼에도 행 수가 작다는 두 번째 이유만으로 결론은 같아
      # `createdAt` 정렬에도 인덱스를 만들지 않는다.
      #
      # "정렬을 여는 변경은 인덱스를 진다"는 규칙이 요구하는 것은 인덱스 자체가
      # 아니라 이 판단의 기록이다.
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
        { "index" => :collection, "show" => :none }.fetch(action_name, :none)
      end

      def allowed_relationships
        {}
      end

      def normalized_resource_id(value)
        identifier = value.to_s
        return identifier.downcase if RESOURCE_UUID.match?(identifier)

        raise JsonApiError.new(status: 404, code: "RESOURCE_NOT_FOUND")
      end
    end
  end
end
