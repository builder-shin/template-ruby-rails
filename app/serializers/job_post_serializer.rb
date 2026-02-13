# frozen_string_literal: true

class JobPostSerializer < ApplicationSerializer
  attributes :id, :workspace_id, :title, :description, :priority, :language_required, :request_count, :view_count, :skills, :contract_conditions, :deadline, :scheduled_publish_date, :published_at, :published_snapshot, :approved_at, :approved_by, :closed_at, :rejection_reason, :status, :employment_type, :deadline_type, :publication_type, :experience_level, :created_at, :updated_at

  has_many :job_applications
  has_many :job_post_categories
  has_many :job_post_jobs
  has_many :jobs
  has_many :job_post_languages
  has_many :job_post_status_logs
end
