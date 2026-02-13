# frozen_string_literal: true

class ProfileEducation < ApplicationRecord
  # Associations
  belongs_to :profile

  # Enums
  enum :education_level, {
    high_school: 0,
    college: 1,
    university: 2,
    masters: 3,
    doctorate: 4,
    integrated_masters_doctorate: 5
  }

  enum :status, {
    enrolled: 0,
    on_leave: 1,
    expected_graduation: 2,
    graduated: 3,
    completed: 4,
    dropped_out: 5
  }

  # Validations
  validates :profile_id, presence: true
  validates :school, presence: true
  validates :major, presence: true
end
