# frozen_string_literal: true

module Api
  module V1
    class ProfileFreelanceExperiencesController < ApiController

      before_action :user_check!
      include ProfileOwnership

      def filter_attributes
        [:profile_id, :company, :project_name, :work_type, :working_hours, :recurring_contract]
      end

      def model_params_options
        {
          only: [
            :profile_id, :company, :project_name, :project_start_date, :project_end_date,
            :role_and_contribution, :working_hours, :weekly_hours, :work_type, :recurring_contract
          ]
        }
      end

      def allowed_includes
        [:profile]
      end
    end
  end
end
