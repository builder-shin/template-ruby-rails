# == Schema Information
#
# Table name: career_hub_event_reviews
#
#  id         :uuid             not null, primary key
#  content    :text             not null
#  created_at :timestamptz      not null
#  deleted_at :timestamptz
#  event_id   :uuid             not null
#  rating     :integer          not null
#  updated_at :timestamptz      not null
#  user_id    :uuid             not null
#
# Indexes
#
#  IDX_career_hub_event_reviews_user_event  (user_id,event_id) UNIQUE WHERE deleted_at IS NULL
#

class CareerHubEventReview < ApplicationRecord
  # Associations
  belongs_to :career_hub_community_event,
             foreign_key: :event_id

  # Validations
  validates :event_id, presence: true
  validates :user_id, presence: true
  validates :content, presence: true
  validates :rating, presence: true,
                     numericality: {
                       only_integer: true,
                       greater_than_or_equal_to: 1,
                       less_than_or_equal_to: 5
                     }
  validates :user_id, uniqueness: { scope: :event_id, conditions: -> { where(deleted_at: nil) } }

  # Scopes
  scope :active, -> { where(deleted_at: nil) }
end
