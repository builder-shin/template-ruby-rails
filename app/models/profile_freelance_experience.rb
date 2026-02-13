# frozen_string_literal: true

class ProfileFreelanceExperience < ApplicationRecord
  # Associations
  belongs_to :profile

  # Enums
  enum :work_type, {
    on_site: 0,
    hybrid: 1,
    remote: 2
  }

  # Validations
  validates :profile_id, presence: true
  validates :company, presence: true
  validates :project_name, presence: true
  validates :project_start_date, presence: true
  validates :role_and_contribution, presence: true
  validates :working_hours, presence: true
  validates :recurring_contract, inclusion: { in: [true, false] }
  validates :weekly_hours, numericality: { only_integer: true, greater_than: 0 }, allow_nil: true
end
