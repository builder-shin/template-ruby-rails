# frozen_string_literal: true

module Api
  module V1
    class CountriesController < ApiController

      def filter_attributes
        [:name]
      end

      def model_params_options
        {
          only: [
            :name
          ]
        }
      end

      def allowed_includes
        []
      end
    end
  end
end
