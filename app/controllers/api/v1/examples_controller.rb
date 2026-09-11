# frozen_string_literal: true

module Api
  module V1
    class ExamplesController < ApiController
      include JsonapiAuthentication

      PROTECTED_WRITE_ACTIONS = %i[
        create
        update
        upsert
        destroy
        replace_category_relationship
        add_tags_relationship
        replace_tags_relationship
        remove_tags_relationship
      ].freeze
      private_constant :PROTECTED_WRITE_ACTIONS

      # 정본에서 확인한 사실: 쓰기 라우트는 get_current_active_user를 쓴다 —
      # authenticate_active_user!가 그 갈래다(JsonapiAuthentication 참고). Bearer
      # access token을 검증하고 User를 조회하고 활성 여부를 보는 것까지 그 하나가
      # 한다. 읽기 액션은 이 목록에 없으므로 어떤 인증도 거치지 않는다.
      before_action :authenticate_active_user!, only: PROTECTED_WRITE_ACTIONS
      skip_before_action :_set_model, only: %i[update destroy]

      def allowed_includes
        %i[category tags]
      end

      private

      def serializer_class
        ExampleSerializer
      end

      def jsonapi_resource_type
        "examples"
      end

      def model_params_options
        { only: %i[title description status score category tags] }
      end

      def required_create_attributes
        %i[title status score]
      end

      def required_replace_attributes
        %i[title status score]
      end

      def write_attribute_rules
        {
          title: { type: :string, min: 1, max: 200 },
          description: { type: :string, nullable: true },
          status: { type: :string, values: %w[draft active archived] },
          score: { type: :integer, min: 0, max: 100 }
        }
      end

      def query_contract
        {
          filters: {
            "title" => { attribute: :title, type: :string, operators: %w[exact contains] },
            "status" => { attribute: :status, type: :enum, operators: %w[exact in] },
            "score" => { attribute: :score, type: :integer, operators: %w[exact gt gte lt lte in] },
            "category.id" => { attribute: :category_id, type: :uuid, operators: %w[exact in isNull] },
            "createdAt" => { attribute: :created_at, type: :datetime, operators: %w[exact gt gte lt lte] }
          },
          sorts: {
            "title" => { attribute: :title, nullable: false },
            "status" => { attribute: :status, nullable: false },
            "score" => { attribute: :score, nullable: false },
            "createdAt" => { attribute: :created_at, nullable: false },
            "updatedAt" => { attribute: :updated_at, nullable: false }
          },
          includes: %w[category tags],
          default_sort: [ { field: "createdAt", direction: :desc } ],
          tie_breaker: { field: "id", direction: :asc },
          default_page_size: 20
        }
      end

      def jsonapi_query_mode
        {
          "index" => :collection,
          "show" => :include_only,
          "related_tags" => :related_collection
        }.fetch(action_name, :none)
      end

      def allowed_relationships
        {
          category: {
            association: :category,
            cardinality: :one,
            type: "exampleCategories",
            serializer: ExampleCategorySerializer,
            model: ExampleCategory
          },
          tags: {
            association: :tags,
            cardinality: :many,
            type: "exampleTags",
            serializer: ExampleTagSerializer,
            model: ExampleTag
          }
        }
      end

      def normalized_resource_id(value)
        Jsonapi::ScalarGrammar.uuid(value.to_s)
      rescue ArgumentError
        raise JsonApiError.new(status: 404, code: "RESOURCE_NOT_FOUND")
      end
    end
  end
end
