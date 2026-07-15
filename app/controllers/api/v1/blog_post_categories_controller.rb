# frozen_string_literal: true

module Api
  module V1
    class BlogPostCategoriesController < ApiController
      before_action :user_check!, except: [ :index, :show ]
      before_action :verify_ownership!, only: [ :update, :destroy ]

      def filter_attributes
        [ :blog_post_id, :category_id ]
      end

      def model_params_options
        { only: [ :blog_post_id, :category_id ] }
      end

      def allowed_includes
        [ :blog_post, :blog_category ]
      end

      private

      def create_after_init
        blog_post = BlogPost.find_by(id: @model.blog_post_id)
        return if blog_post&.author_id == user_info.id
        raise ::JsonApiError.new(status: 403, code: "FORBIDDEN")
      end

      def verify_ownership!
        return if @model.blog_post&.author_id == user_info.id
        raise ::JsonApiError.new(status: 403, code: "FORBIDDEN")
      end
    end
  end
end
