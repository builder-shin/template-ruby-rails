class ProfileLink < ApplicationRecord
  # Associations
  belongs_to :profile

  # Validations
  validates :url, presence: true, length: { maximum: 2048 }
  validates :profile_id, presence: true
end
