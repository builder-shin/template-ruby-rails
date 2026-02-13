class ApplicationContextReference < ApplicationRecord
  # Associations
  belongs_to :job_category

  # Validations
  validates :job_category_id, presence: true
  validates :reference, presence: true
end
