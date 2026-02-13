# frozen_string_literal: true

module Api
  module V1
    class EventNotificationSchedulesController < ApiController
      before_action :user_check!

      def filter_attributes
        [:name, :enabled, :target_type, :trigger_type]
      end

      def model_params_options
        {
          only: [
            :name, :email_subject, :sendgrid_template_id, :enabled,
            :target_type, :trigger_type, :trigger_value, :send_time, :last_executed_at
          ]
        }
      end

      def allowed_includes
        []
      end
    end
  end
end
