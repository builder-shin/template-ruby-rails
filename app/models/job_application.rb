class JobApplication < ApplicationRecord
  # Associations
  belongs_to :job_post
  belongs_to :profile

  # Enums
  enum :status, {
    submitted: 0,
    under_review: 1,
    document_passed: 2,
    accepted: 3,
    final_passed: 4,
    rejected: 5,
    canceled: 6
  }

  # Validations
  validates :job_post_id, presence: true
  validates :profile_id, presence: true
  validates :profile_snapshot, presence: true
  validates :submitted_at, presence: true

  # 중복 지원 방지 (취소된 지원은 제외)
  validates :profile_id, uniqueness: {
    scope: :job_post_id,
    conditions: -> { where.not(status: :canceled) },
    message: "이미 해당 공고에 지원하셨습니다."
  }

  # 모집 중인 공고에만 지원 가능
  validate :job_post_must_be_recruiting, on: :create

  # Callbacks
  before_save :validate_status_transition, if: :status_changed?

  private

  # 유효한 상태 전환 맵
  VALID_TRANSITIONS = {
    nil             => %w[submitted],
    "submitted"     => %w[under_review canceled],
    "under_review"  => %w[document_passed rejected canceled],
    "document_passed" => %w[accepted rejected canceled],
    "accepted"      => %w[final_passed rejected],
    "final_passed"  => [],
    "rejected"      => [],
    "canceled"      => []
  }.freeze

  def validate_status_transition
    old_status = status_was
    new_status = status

    allowed = VALID_TRANSITIONS[old_status] || []
    return if allowed.include?(new_status)

    errors.add(:status, "유효하지 않은 상태 전환입니다: #{old_status || 'nil'} → #{new_status}")
    throw(:abort)
  end

  def job_post_must_be_recruiting
    return if job_post.blank?
    return if job_post.recruiting?

    errors.add(:job_post, "모집 중인 공고에만 지원할 수 있습니다.")
  end
end
