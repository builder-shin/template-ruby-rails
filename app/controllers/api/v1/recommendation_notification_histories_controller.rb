# frozen_string_literal: true

module Api
  module V1
    class RecommendationNotificationHistoriesController < ApiController
      before_action :user_check!

      def filter_attributes
        [:sender_id, :recipient_id, :job_post_id, :type, :recipient_email]
      end

      def model_params_options
        {
          only: [:sender_id, :recipient_id, :job_post_id, :type, :recipient_email, :sent_at]
        }
      end

      def allowed_includes
        [:job_post]
      end
    end
  end
end
