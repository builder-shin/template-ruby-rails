# frozen_string_literal: true

class CareerHubCommunityFeedLikeSerializer < ApplicationSerializer
  attributes :id, :feed_id, :user_id, :created_at

  belongs_to :career_hub_community_feed, id_method_name: :feed_id
end
