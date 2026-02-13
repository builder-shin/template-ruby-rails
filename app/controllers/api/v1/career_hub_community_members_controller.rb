# frozen_string_literal: true

module Api
  module V1
    class CareerHubCommunityMembersController < ApiController

      before_action :user_check!
      before_action :verify_ownership!, only: [:update, :destroy]

      def filter_attributes
        [ :community_id, :user_id, :status, :role ]
      end

      def model_params_options
        {
          only: [
            :community_id, :answers
          ]
        }
      end

      def allowed_includes
        [ :career_hub_community ]
      end

      private

      def create_after_init
        @model.user_id = user_info.id
        @model.joined_at ||= Time.current
        @model.status ||= "pending"
        @model.answers ||= []
      end

      def update_after_assign
        return unless @model.community_id_changed?

        raise JsonApiError.new("Forbidden", "커뮤니티 변경은 허용되지 않습니다.", 403)
      end

      def verify_ownership!
        return if @model.user_id == user_info.id

        raise JsonApiError.new("Forbidden", "자신의 멤버십만 수정할 수 있습니다.", 403)
      end
    end
  end
end
