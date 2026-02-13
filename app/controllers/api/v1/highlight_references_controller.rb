# frozen_string_literal: true

module Api
  module V1
    class HighlightReferencesController < ApiController

      def filter_attributes
        [:job_category_id, :highlight_type, :reference]
      end

      def model_params_options
        { only: [:job_category_id, :reference, :highlight_type] }
      end

      def allowed_includes
        [:job_category]
      end
    end
  end
end
