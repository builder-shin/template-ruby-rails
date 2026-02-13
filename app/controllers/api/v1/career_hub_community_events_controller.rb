# frozen_string_literal: true

module Api
  module V1
    class CareerHubCommunityEventsController < ApiController

      before_action :user_check!, except: [:index, :show]

      def filter_attributes
        [:title, :status, :event_type, :community_id, :location_type, :end_at]
      end

      def model_params_options
        {
          only: [
            :title, :description, :event_type,
            :community_id, :thumbnail_url,
            :start_at, :end_at, :location, :location_type, :meeting_link,
            :max_participants, :price,
            :registration_start_at, :registration_end_at,
            :publish_at, :tags
          ]
        }
      end

      def allowed_includes
        [:career_hub_community]
      end

      private

      def create_after_init
        community_leader_check!(@model.community_id)
      end

      def update_after_init
        community_leader_check!(@model.community_id)
      end

      def update_after_assign
        return unless @model.community_id_changed?

        community_leader_check!(@model.community_id)
      end

      def destroy_after_init
        community_leader_check!(@model.community_id)
      end
    end
  end
end
