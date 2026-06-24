# frozen_string_literal: true

module Api
  module V1
    class ProfileProjectsController < ApiController

      before_action :user_check!
      include ProfileOwnership

      def filter_attributes
        [:profile_id, :company, :project_name, :working_hours]
      end

      def model_params_options
        {
          only: [
            :profile_id, :company, :project_name, :project_start_date, :project_end_date,
            :background_or_goal, :role, :tools, :result, :working_hours, :weekly_hours
          ]
        }
      end

      def allowed_includes
        [:profile]
      end
    end
  end
end
