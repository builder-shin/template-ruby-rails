# frozen_string_literal: true

module Api
  module V1
    class BlogCategoriesController < ApiController
      # Routes: only: [:index, :show] — read-only resource

      def filter_attributes
        [ :name, :slug, :level, :status, :parent_id ]
      end

      def allowed_includes
        [ :parent, :children, :blog_posts ]
      end
    end
  end
end
