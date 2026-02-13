# frozen_string_literal: true

class CareerHubCommunityFeedSerializer < ApplicationSerializer
  attributes :id, :community_id, :author_id, :content,
             :parent_id, :root_id, :status,
             :pinned, :pinned_at, :content_edited_at,
             :likes_count, :replies_count,
             :created_at, :updated_at

  belongs_to :career_hub_community, id_method_name: :community_id
  belongs_to :parent, serializer: :career_hub_community_feed
  belongs_to :root, serializer: :career_hub_community_feed

  has_many :replies
  has_many :career_hub_community_feed_likes
end
