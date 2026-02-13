# frozen_string_literal: true

module Api
  module V1
    class JobsController < ApiController

      def filter_attributes
        [:job_category_id, :name]
      end

      def model_params_options
        { only: [:job_category_id, :name] }
      end

      def allowed_includes
        [:job_category]
      end
    end
  end
end
