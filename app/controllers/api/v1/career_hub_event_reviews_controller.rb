# frozen_string_literal: true

module Api
  module V1
    class CareerHubEventReviewsController < ApiController
      before_action :user_check!, except: [:index, :show]
      before_action :verify_ownership!, only: [:update, :destroy]

      def filter_attributes
        [:event_id, :user_id, :rating]
      end

      def model_params_options
        {
          only: [
            :event_id, :content, :rating
          ]
        }
      end

      def allowed_includes
        [:career_hub_community_event]
      end

      private

      def create_after_init
        @model.user_id = user_info.id
      end

      def verify_ownership!
        return if @model.user_id == user_info.id
        raise JsonApiError.new("Forbidden", "자신의 리뷰만 수정할 수 있습니다.", 403)
      end
    end
  end
end
