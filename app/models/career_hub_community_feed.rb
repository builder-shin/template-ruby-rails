class CareerHubCommunityFeed < ApplicationRecord
  # Enums
  enum :status, {
    active: 0,
    deleted: 1,
    hidden: 2
  }, prefix: true

  # Associations
  belongs_to :career_hub_community, foreign_key: :community_id
  belongs_to :parent, class_name: 'CareerHubCommunityFeed', optional: true
  belongs_to :root, class_name: 'CareerHubCommunityFeed', optional: true

  has_many :replies, class_name: 'CareerHubCommunityFeed', foreign_key: :parent_id, dependent: :restrict_with_error
  has_many :career_hub_community_feed_likes, foreign_key: :feed_id, dependent: :destroy

  # Callbacks
  after_create :increment_parent_replies_count
  before_destroy :decrement_parent_replies_count

  # Scopes
  scope :visible, -> { where.not(status: :deleted) }

  # Validations
  validates :author_id, presence: true
  validates :community_id, presence: true
  validates :content, presence: true
  validates :likes_count, presence: true
  validates :replies_count, presence: true

  private

  def increment_parent_replies_count
    return unless parent_id

    CareerHubCommunityFeed.update_counters(parent_id, replies_count: 1)
  end

  def decrement_parent_replies_count
    return unless parent_id

    CareerHubCommunityFeed.update_counters(parent_id, replies_count: -1)
  end
end
