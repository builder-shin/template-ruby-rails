class JobPostJob < ApplicationRecord
  # Composite primary key
  self.primary_key = [:job_post_id, :job_id]

  # Associations
  belongs_to :job_post
  belongs_to :job

  # Validations
  validates :job_post_id, presence: true
  validates :job_id, presence: true
end
