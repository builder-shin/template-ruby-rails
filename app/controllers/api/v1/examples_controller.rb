# frozen_string_literal: true

module Api
  module V1
    class ExamplesController < ApiController
      RESOURCE_UUID = /\A[0-9a-f]{8}(?:-[0-9a-f]{4}){3}-[0-9a-f]{12}\z/i
      private_constant :RESOURCE_UUID

      before_action :require_active_user!, only: %i[
        create
        update
        upsert
        destroy
        replace_category_relationship
        add_tags_relationship
        replace_tags_relationship
        remove_tags_relationship
      ]
      skip_before_action :_set_model, only: :update

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

      def query_contract
        {
          filters: {
            "title" => %w[exact contains],
            "status" => %w[exact in],
            "score" => %w[exact gt gte lt lte in],
            "category.id" => %w[exact in isNull],
            "createdAt" => %w[exact gt gte lt lte]
          },
          sorts: %w[title status score createdAt updatedAt],
          includes: %w[category tags]
        }
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
        identifier = value.to_s
        return identifier.downcase if RESOURCE_UUID.match?(identifier)

        raise JsonApiError.new(status: 404, code: "RESOURCE_NOT_FOUND")
      end
    end
  end
end
