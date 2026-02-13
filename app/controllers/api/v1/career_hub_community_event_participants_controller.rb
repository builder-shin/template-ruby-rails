# frozen_string_literal: true

module Api
  module V1
    class CareerHubCommunityEventParticipantsController < ApiController

      before_action :user_check!
      before_action :verify_ownership!, only: [:update, :destroy]

      def filter_attributes
        [ :event_id, :user_id, :name, :status ]
      end

      def model_params_options
        {
          only: [
            :event_id, :name, :company, :requests
          ]
        }
      end

      def allowed_includes
        [ :career_hub_community_event ]
      end

      private

      def index_scope
        return klass.all if params.dig(:filter, :event_id).present?

        klass.where(user_id: user_info.id)
      end

      def create_after_init
        @model.user_id = user_info.id
        @model.name ||= user_info.name
        @model.email ||= user_info.email
        @model.status ||= "registered"
      end

      def verify_ownership!
        return if @model.user_id == user_info.id

        raise JsonApiError.new("Forbidden", "자신의 참여 정보만 수정할 수 있습니다.", 403)
      end
    end
  end
end
