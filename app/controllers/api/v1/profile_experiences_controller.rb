# frozen_string_literal: true

module Api
  module V1
    class ProfileExperiencesController < ApiController

      before_action :user_check!
      include ProfileOwnership

      def filter_attributes
        [:profile_id, :company, :position, :current, :is_featured, :work_type]
      end

      def model_params_options
        {
          only: [
            :profile_id, :company, :position, :start_date, :end_date,
            :current, :is_featured, :work_type
          ]
        }
      end

      def allowed_includes
        [:profile]
      end
    end
  end
end
