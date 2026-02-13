# frozen_string_literal: true

module Api
  module V1
    class ProfileExperiencesController < ApiController

      before_action :user_check!
      before_action :personal_check!, only: [:create, :update, :destroy]
      before_action :verify_ownership!, only: [:update, :destroy]

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

      private

      def create_after_init
        return if @model.profile&.user_id == user_info.id

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
