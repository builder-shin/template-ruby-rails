class ProfileProject < ApplicationRecord
  # Associations
  belongs_to :profile

  # Validations
  validates :background_or_goal, presence: true
  validates :company, presence: true
  validates :profile_id, presence: true
  validates :project_name, presence: true
  validates :project_start_date, presence: true
  validates :result, presence: true
  validates :role, presence: true
  validates :tools, presence: true
  validates :working_hours, presence: true
end
