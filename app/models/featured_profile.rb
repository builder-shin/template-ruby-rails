# == Schema Information
#
# Table name: featured_profiles
#
#  id            :uuid             not null, primary key
#  created_at    :timestamp        not null
#  display_order :integer          not null, default(0)
#  is_active     :boolean          not null, default(true)
#  profile_id    :uuid             not null
#  updated_at    :timestamp        not null
#
# Indexes
#
#  IDX_8ae157342fdd9718939b0a6f3c              (display_order)
#  IDX_a2eae56d3d6401ca3443973ada              (profile_id) UNIQUE
#  IDX_fac5c3b26589fb87762c976288              (is_active)
#  REL_a2eae56d3d6401ca3443973ada              (profile_id) UNIQUE
#

class FeaturedProfile < ApplicationRecord
  # Associations
  belongs_to :profile

  # Validations
  validates :profile_id, presence: true, uniqueness: true
  validates :display_order, presence: true, numericality: { only_integer: true }
  validates :is_active, inclusion: { in: [true, false] }

  # Scopes
  scope :active, -> { where(is_active: true) }
  scope :ordered, -> { order(display_order: :asc) }
end
