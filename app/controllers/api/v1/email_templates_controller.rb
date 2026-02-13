# frozen_string_literal: true

module Api
  module V1
    class EmailTemplatesController < ApiController
      before_action :user_check!

      def filter_attributes
        [:key, :name, :is_enabled]
      end

      def model_params_options
        {
          only: [
            :key, :name, :description, :subject, :sendgrid_template_id, :is_enabled
          ]
        }
      end

      def allowed_includes
        []
      end
    end
  end
end
