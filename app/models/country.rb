# == Schema Information
#
# Table name: countries
#
#  id         :uuid             not null, primary key
#  created_at :timestamp        not null
#  name       :string           not null
#  updated_at :timestamp        not null
#
# Indexes
#
#  IDX_fa1376321185575cf2226b1491  (name) UNIQUE
#

class Country < ApplicationRecord
  # Associations
  has_many :profiles,
           foreign_key: :nationality_id,
           dependent: :restrict_with_error

  # Validations
  validates :name, presence: true, uniqueness: true
end
