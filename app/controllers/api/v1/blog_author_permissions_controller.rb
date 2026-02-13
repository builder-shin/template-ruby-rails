# frozen_string_literal: true

module Api
  module V1
    class BlogAuthorPermissionsController < ApiController
      before_action :user_check!
      before_action :verify_ownership!, only: [:update, :destroy]

      def filter_attributes
        [:author_id, :author_type, :status]
      end

      def model_params_options
        {
          only: [
            :author_type
          ]
        }
      end

      private

      def index_scope
        klass.where(author_id: user_info.id)
      end

      def create_after_init
        @model.author_id = user_info.id
      end

      def verify_ownership!
        return if @model.author_id == user_info.id
        raise JsonApiError.new("Forbidden", "자신의 권한 요청만 수정할 수 있습니다.", 403)
      end
    end
  end
end
