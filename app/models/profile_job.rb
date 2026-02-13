class ProfileJob < ApplicationRecord
  # Composite primary key
  self.primary_key = [:profile_id, :job_id]

  # Associations
  belongs_to :profile
  belongs_to :job

  # Validations
  validates :profile_id, presence: true
  validates :job_id, presence: true
end
