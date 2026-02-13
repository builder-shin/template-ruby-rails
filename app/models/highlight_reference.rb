class HighlightReference < ApplicationRecord
  # Associations
  belongs_to :job_category

  # Enums
  enum :highlight_type, {
    before: 0,
    action: 1,
    after: 2
  }

  # Validations
  validates :job_category_id, presence: true
  validates :reference, presence: true
end
