class ProfileLanguage < ApplicationRecord
  # Enums
  enum :proficiency, {
    basic: 0,
    conversational: 1,
    business: 2,
    fluent: 3,
    native: 4
  }

  # Associations
  belongs_to :profile

  # Validations
  validates :language, presence: true
  validates :profile_id, presence: true
end
