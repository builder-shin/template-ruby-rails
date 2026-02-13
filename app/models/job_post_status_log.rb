class JobPostStatusLog < ApplicationRecord
  # Associations
  belongs_to :job_post

  # Enums
  enum :changed_by_type, {
    admin: 0,
    company: 1,
    system: 2
  }

  enum :from_status, {
    draft: 0,
    completed: 1,
    pending_review: 2,
    pending_publish: 3,
    recruiting: 4,
    closed: 5,
    rejected: 6,
    company_stopped: 7,
    admin_stopped: 8
  }, prefix: :from

  enum :to_status, {
    draft: 0,
    completed: 1,
    pending_review: 2,
    pending_publish: 3,
    recruiting: 4,
    closed: 5,
    rejected: 6,
    company_stopped: 7,
    admin_stopped: 8
  }, prefix: :to

  # Validations
  validates :job_post_id, presence: true
  validates :changed_at, presence: true
end
