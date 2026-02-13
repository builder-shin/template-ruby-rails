class CareerHubCommunity < ApplicationRecord
  # Enums
  enum :status, {
    pending: 0,
    active: 1,
    inactive: 2,
    suspended: 3
  }, prefix: true

  enum :join_policy, {
    open: 0,
    approval: 1
  }, prefix: true

  # Associations
  belongs_to :career_hub_category, foreign_key: :category_id, optional: true
  belongs_to :career_hub_subcategory, class_name: 'CareerHubCategory', foreign_key: :subcategory_id, optional: true
  belongs_to :career_hub_community_leader, foreign_key: :leader_id, optional: true

  has_many :career_hub_community_members, foreign_key: :community_id, dependent: :destroy
  has_many :career_hub_community_events, foreign_key: :community_id, dependent: :destroy
  has_many :career_hub_community_feeds, foreign_key: :community_id, dependent: :destroy

  # Validations
  validates :title, presence: true
  validates :participants_count, presence: true
end
