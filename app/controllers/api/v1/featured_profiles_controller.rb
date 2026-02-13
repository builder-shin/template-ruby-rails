# frozen_string_literal: true

module Api
  module V1
    class FeaturedProfilesController < ApiController
      before_action :user_check!, except: [:index, :show]

      def filter_attributes
        [:profile_id, :is_active]
      end

      def model_params_options
        {
          only: [
            :profile_id, :display_order, :is_active
          ]
        }
      end

      def allowed_includes
        [
          :profile,
          :"profile.job_category",
          :"profile.user",
          :"profile.nationality",
          :"profile.profile_experiences",
          :"profile.profile_freelance_experiences",
          :"profile.jobs"
        ]
      end
    end
  end
end
