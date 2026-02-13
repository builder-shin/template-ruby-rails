# frozen_string_literal: true

class JobApplicationSerializer < ApplicationSerializer
  attributes :id, :job_post_id, :profile_id, :email, :phone, :profile_snapshot, :submitted_at, :reviewed_at, :processed_at, :profile_viewed_at, :rejection_reason, :status, :created_at, :updated_at

  belongs_to :job_post
  belongs_to :profile
end
