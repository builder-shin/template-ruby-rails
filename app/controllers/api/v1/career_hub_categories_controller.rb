# frozen_string_literal: true

module Api
  module V1
    class CareerHubCategoriesController < ApiController

      def filter_attributes
        [:category_idx, :key, :level, :name, :parent_id, :active, :visible]
      end

      def model_params_options
        {
          only: [
            :category_idx, :key, :level, :name, :display_order,
            :parent_id, :parent_idx, :active, :visible,
            :description, :color, :icon_name, :icon_url
          ]
        }
      end

      def allowed_includes
        [:parent]
      end
    end
  end
end
