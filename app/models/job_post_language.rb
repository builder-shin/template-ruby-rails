class JobPostLanguage < ApplicationRecord
  # Associations
  belongs_to :job_post

  # Enums
  enum :proficiency, {
    basic: 0,
    conversational: 1,
    business: 2,
    fluent: 3,
    native: 4
  }

  # Validations
  validates :job_post_id, presence: true
  validates :language, presence: true
end
