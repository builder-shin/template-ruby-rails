# == Schema Information
#
# Table name: career_hub_community_members
#
#  id           :uuid             not null, primary key
#  answers      :jsonb            not null, default([])
#  community_id :uuid
#  created_at   :timestamptz      not null
#  joined_at    :timestamptz      not null
#  role         :string(50)       not null, default("member")
#  status       :integer
#  updated_at   :timestamptz      not null
#  user_id      :uuid
#

class CareerHubCommunityMember < ApplicationRecord
  # Enums
  enum :status, {
    pending: 0,
    active: 1,
    inactive: 2,
    banned: 3
  }, prefix: true

  # Associations
  belongs_to :career_hub_community,
             foreign_key: :community_id,
             optional: true

  # Callbacks
  after_create :increment_participants_count
  after_destroy :decrement_participants_count

  # Validations
  validate :answers_must_be_array
  validate :community_capacity, on: :create
  validates :role, presence: true
  validates :joined_at, presence: true
  validates :user_id, uniqueness: { scope: :community_id, message: "이미 가입된 커뮤니티입니다" }

  private

  def answers_must_be_array
    return if answers.is_a?(Array)

    errors.add(:answers, "배열 형식이어야 합니다")
  end

  def community_capacity
    return unless career_hub_community
    locked = CareerHubCommunity.lock.find(career_hub_community.id)
    max = locked.max_participants
    return if max.blank? || max <= 0

    if locked.participants_count >= max
      errors.add(:base, "커뮤니티 최대 참여 인원을 초과했습니다")
    end
  end

  def increment_participants_count
    return unless community_id

    CareerHubCommunity.update_counters(community_id, participants_count: 1)
  end

  def decrement_participants_count
    return unless community_id

    CareerHubCommunity.update_counters(community_id, participants_count: -1)
  end
end
