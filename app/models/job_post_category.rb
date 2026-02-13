class JobPostCategory < ApplicationRecord
  # Composite primary key
  self.primary_key = [:job_post_id, :job_category_id]

  # Associations
  belongs_to :job_post
  belongs_to :job_category

  # Validations
  validates :job_post_id, presence: true
  validates :job_category_id, presence: true
end
