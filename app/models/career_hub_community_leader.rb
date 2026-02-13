# == Schema Information
#
# Table name: career_hub_community_leaders
#
#  id                 :uuid             not null, primary key
#  avatar_url         :string(2048)
#  bio                :text
#  created_at         :timestamptz      not null
#  current_company    :string(255)
#  current_position   :string(255)
#  detailed_bio       :jsonb
#  display_name       :string(255)
#  experiences        :jsonb            not null, default([])
#  name               :string(255)      not null
#  quote              :text
#  social_links       :jsonb            not null, default([])
#  status             :integer
#  updated_at         :timestamptz      not null
#  verification_badge :boolean          not null, default(false)
#  user_id            :uuid
#

class CareerHubCommunityLeader < ApplicationRecord
  # Enums
  enum :status, {
    pending: 0,
    approved: 1,
    rejected: 2,
    suspended: 3
  }, prefix: true

  # Associations
  has_many :career_hub_communities,
           foreign_key: :leader_id,
           dependent: :nullify

  # Validations
  validates :name, presence: true
  validates :experiences, presence: true
  validates :social_links, presence: true
  validates :verification_badge, inclusion: { in: [true, false] }
end
