class CareerHubCommunityEventParticipant < ApplicationRecord
  # Enums
  enum :status, {
    registered: 0,
    confirmed: 1,
    cancelled: 2,
    attended: 3,
    no_show: 4
  }, prefix: true

  # Associations
  belongs_to :career_hub_community_event, foreign_key: :event_id, optional: true

  # Callbacks
  after_create :increment_participants_count
  after_destroy :decrement_participants_count

  # Validations
  validates :name, presence: true
  validates :email, presence: true
  validates :user_id, uniqueness: { scope: :event_id, message: "이미 참여 신청한 이벤트입니다" }
  validate :event_capacity, on: :create

  private

  def event_capacity
    return unless career_hub_community_event
    locked = CareerHubCommunityEvent.lock.find(career_hub_community_event.id)
    max = locked.max_participants
    return if max.blank? || max <= 0

    if locked.participants_count >= max
      errors.add(:base, "이벤트 최대 참여 인원을 초과했습니다")
    end
  end

  def increment_participants_count
    return unless event_id

    CareerHubCommunityEvent.update_counters(event_id, participants_count: 1)
  end

  def decrement_participants_count
    return unless event_id

    CareerHubCommunityEvent.update_counters(event_id, participants_count: -1)
  end
end
