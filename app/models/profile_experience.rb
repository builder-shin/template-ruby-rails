# frozen_string_literal: true

class ProfileExperience < ApplicationRecord
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
  validates :position, presence: true
  validates :start_date, presence: true
  validates :current, inclusion: { in: [true, false] }
  validates :is_featured, inclusion: { in: [true, false] }
end
