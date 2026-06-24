# frozen_string_literal: true

module Api
  module V1
    class ProfileEducationsController < ApiController

      before_action :user_check!
      include ProfileOwnership

      def filter_attributes
        [:profile_id, :education_level, :status, :school, :major]
      end

      def model_params_options
        {
          only: [
            :profile_id, :school, :major, :minor, :double_major,
            :education_level, :status, :enrollment_date, :graduation_date
          ]
        }
      end

      def allowed_includes
        [:profile]
      end
    end
  end
end
