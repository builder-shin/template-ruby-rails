# frozen_string_literal: true

module Api
  module V1
    class ProfileJobsController < ApiController
      before_action :user_check!, except: [:index, :show]
      include ProfileOwnership

      def filter_attributes
        [:profile_id, :job_id]
      end

      def model_params_options
        {
          only: [:profile_id, :job_id]
        }
      end

      def allowed_includes
        [:profile, :job]
      end
    end
  end
end
