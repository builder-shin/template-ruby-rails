class ProfileHighlight < ApplicationRecord
  # Associations
  belongs_to :profile

  # Validations
  validates :after, presence: true
  validates :details, presence: true
  validates :profile_id, presence: true
end
