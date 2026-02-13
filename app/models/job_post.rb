# frozen_string_literal: true

class JobPost < ApplicationRecord
  # Associations
  has_many :job_applications, dependent: :destroy
  has_many :job_post_categories, dependent: :destroy
  has_many :job_post_jobs, dependent: :destroy
  has_many :jobs, through: :job_post_jobs
  has_many :job_post_languages, dependent: :destroy
  has_many :job_post_status_logs, dependent: :destroy

  # Enums
  enum :status, {
    draft: 0,
    completed: 1,
    pending_review: 2,
    pending_publish: 3,
    recruiting: 4,
    closed: 5,
    rejected: 6,
    company_stopped: 7,
    admin_stopped: 8
  }

  enum :employment_type, {
    freelancer: 0,
    contract: 1,
    full_time: 2
  }

  enum :deadline_type, {
    until_filled: 0,
    fixed_date: 1
  }

  enum :publication_type, {
    immediate: 0,
    scheduled: 1
  }

  enum :experience_level, {
    under_5_years: 0,
    from_5_to_10_years: 1,
    from_10_to_20_years: 2,
    over_20_years: 3
  }

  # Validations
  validates :workspace_id, presence: true
  validates :title, presence: true, length: { maximum: 255 }
  validates :description, presence: true
  validates :priority, inclusion: { in: [true, false] }
  validates :language_required, inclusion: { in: [true, false] }
  validates :request_count, numericality: { only_integer: true, greater_than_or_equal_to: 0 }
  validates :view_count, numericality: { only_integer: true, greater_than_or_equal_to: 0 }

  # Callbacks
  before_save :validate_status_transition, if: :status_changed?
  before_save :save_published_snapshot, if: :recruiting?
  before_save :set_timestamps_on_status_change, if: :status_changed?
  before_save :increment_request_count_on_review, if: :status_changed?
  after_save :create_status_log, if: :saved_change_to_status?

  private

  # 유효한 상태 전환 맵
  VALID_TRANSITIONS = {
    nil             => %w[draft],
    "draft"         => %w[completed],
    "completed"     => %w[pending_review],
    "pending_review" => %w[recruiting pending_publish rejected completed],
    "pending_publish" => %w[recruiting completed],
    "recruiting"    => %w[closed company_stopped admin_stopped],
    "company_stopped" => %w[completed],
    "rejected"      => %w[completed],
    "closed"        => %w[completed],
    "admin_stopped" => []
  }.freeze

  CONTENT_FIELDS = %w[title description skills contract_conditions employment_type deadline_type
                      publication_type experience_level deadline language_required priority].freeze

  def validate_status_transition
    old_status = status_was
    new_status = status

    allowed = VALID_TRANSITIONS[old_status] || []
    return if allowed.include?(new_status)

    errors.add(:status, "유효하지 않은 상태 전환입니다: #{old_status || 'nil'} → #{new_status}")
    throw(:abort)
  end

  def save_published_snapshot
    # recruiting 상태에서 컨텐츠 필드가 변경되면 이전 게시 버전을 스냅샷에 저장
    return if status_changed? # 최초 recruiting 전환 시에는 스냅샷 불필요

    changed_content = changes.keys & CONTENT_FIELDS
    return if changed_content.empty?

    snapshot = {}
    CONTENT_FIELDS.each do |field|
      # 변경된 필드는 이전 값, 변경되지 않은 필드는 현재 값
      snapshot[field] = if changes.key?(field)
                          changes[field].first
                        else
                          send(field)
                        end
    end
    self.published_snapshot = snapshot
  end

  def set_timestamps_on_status_change
    new_status = status

    case new_status
    when "recruiting"
      self.published_at = Time.current
    when "closed", "company_stopped", "admin_stopped"
      self.closed_at = Time.current
    end
  end

  def increment_request_count_on_review
    return unless status == "pending_review"

    self.request_count = (request_count || 0) + 1
  end

  def create_status_log
    old_int = saved_changes["status"]&.first
    new_int = saved_changes["status"]&.last

    job_post_status_logs.create!(
      from_status: old_int.present? ? self.class.statuses.key(old_int) : nil,
      to_status: self.class.statuses.key(new_int),
      changed_at: Time.current
    )
  end
end
