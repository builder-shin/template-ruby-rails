# frozen_string_literal: true

module Api
  module V1
    class CareerHubCommunityFeedLikesController < ApiController

      before_action :user_check!, except: [:index, :show]
      before_action :verify_ownership!, only: [:destroy]

      def filter_attributes
        [:feed_id, :user_id]
      end

      def model_params_options
        { only: [:feed_id] }
      end

      def allowed_includes
        [:career_hub_community_feed]
      end

      private

      def create_after_init
        @model.user_id = user_info.id
      end

      def verify_ownership!
        return if @model.user_id == user_info.id
        raise JsonApiError.new("Forbidden", "자신의 좋아요만 삭제할 수 있습니다.", 403)
      end
    end
  end
end
