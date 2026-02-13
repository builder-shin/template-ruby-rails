class CareerHubCommunityEvent < ApplicationRecord
  # Enums
  enum :status, {
    draft: 0,
    pending: 1,
    scheduled: 2,
    active: 3,
    completed: 4,
    closed: 5,
    cancelled: 6,
    suspended: 7
  }, prefix: true

  # Associations
  belongs_to :career_hub_community, foreign_key: :community_id, optional: true

  has_many :career_hub_community_event_participants, foreign_key: :event_id, dependent: :destroy

  # Validations
  validates :title, presence: true
  validates :event_type, presence: true
  validates :participants_count, presence: true
  validates :price, presence: true
end
