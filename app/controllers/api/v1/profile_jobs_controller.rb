# frozen_string_literal: true

module Api
  module V1
    class ProfileJobsController < ApiController
      before_action :user_check!, except: [:index, :show]
      before_action :personal_check!, only: [:create, :update, :destroy]
      before_action :verify_ownership!, only: [:update, :destroy]

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

      private

      def create_after_init
        profile = Profile.find_by(id: @model.profile_id)
        return if profile&.user_id == user_info.id
        raise JsonApiError.new("Forbidden", "자신의 프로필에만 추가할 수 있습니다.", 403)
      end

      def verify_ownership!
        profile = @model.profile
        return if profile&.user_id == user_info.id
        raise JsonApiError.new("Forbidden", "자신의 리소스만 수정할 수 있습니다.", 403)
      end
    end
  end
end
