# frozen_string_literal: true

module Api
  module V1
    class CareerHubCommunitiesController < ApiController
      before_action :user_check!, except: [:index, :show]

      def filter_attributes
        [:title, :status, :join_policy, :category_id, :subcategory_id, :leader_id, :slug]
      end

      def model_params_options
        {
          only: [
            :title, :description, :status, :join_policy,
            :category_id, :subcategory_id,
            :thumbnail_url, :slug, :schedule, :duration,
            :max_participants,
            :intro_content, :questions, :tags
          ]
        }
      end

      def allowed_includes
        [:career_hub_category, :career_hub_subcategory, :career_hub_community_leader]
      end

      private

      def create_after_init
        leader = CareerHubCommunityLeader.find_by(user_id: user_info.id, status: :approved)
        raise JsonApiError.new("Forbidden", "승인된 커뮤니티 리더만 커뮤니티를 생성할 수 있습니다.", 403) unless leader
        @model.leader_id = leader.id
      end

      def update_after_init
        community_leader_check!(@model.id)
      end

      def destroy_after_init
        community_leader_check!(@model.id)
      end
    end
  end
end
