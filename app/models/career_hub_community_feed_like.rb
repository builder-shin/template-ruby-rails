class CareerHubCommunityFeedLike < ApplicationRecord
  # Associations
  belongs_to :career_hub_community_feed, foreign_key: :feed_id

  # Callbacks
  after_create :increment_likes_count
  after_destroy :decrement_likes_count

  # Validations
  validates :feed_id, presence: true
  validates :user_id, presence: true
  validates :user_id, uniqueness: { scope: :feed_id }

  private

  def increment_likes_count
    CareerHubCommunityFeed.update_counters(feed_id, likes_count: 1)
  end

  def decrement_likes_count
    CareerHubCommunityFeed.update_counters(feed_id, likes_count: -1)
  end
end
