# frozen_string_literal: true

module Api
  module V1
    class CareerHubCommunityLeadersController < ApiController

      before_action :user_check!, except: [:index, :show]
      before_action :verify_ownership!, only: [:update, :destroy]

      def filter_attributes
        [:name, :status, :verification_badge, :current_company, :current_position, :user_id]
      end

      def model_params_options
        {
          only: [
            :name, :display_name, :bio, :quote, :avatar_url,
            :current_company, :current_position, :verification_badge,
            :experiences, :social_links, :detailed_bio
          ]
        }
      end

      def allowed_includes
        []
      end

      private

      def create_after_init
        @model.user_id = user_info.id
      end

      def verify_ownership!
        return if @model.user_id == user_info.id
        raise JsonApiError.new("Forbidden", "자신의 리더 프로필만 수정할 수 있습니다.", 403)
      end
    end
  end
end
