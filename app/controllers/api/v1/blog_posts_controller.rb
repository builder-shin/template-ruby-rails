# frozen_string_literal: true

module Api
  module V1
    class BlogPostsController < ApiController
      before_action :user_check!, except: [ :index, :show ]
      before_action :verify_ownership!, only: [ :update, :destroy ]

      def filter_attributes
        [ :author_id, :author_type, :status, :slug, :publish_date ]
      end

      def model_params_options
        {
          only: [
            :title, :slug, :content,
            :description, :meta_description, :main_image, :main_image_size,
            :tags, :status, :publish_date
          ]
        }
      end

      def allowed_includes
        [ :blog_categories, :blog_views ]
      end

      private

      def create_after_init
        @model.author_id = user_info.id
      end

      def verify_ownership!
        return if @model.author_id == user_info.id
        raise JsonApiError.new("Forbidden", "자신의 블로그 포스트만 수정할 수 있습니다.", 403)
      end
    end
  end
end
