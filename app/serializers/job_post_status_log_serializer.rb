# frozen_string_literal: true

class JobPostStatusLogSerializer < ApplicationSerializer
  attributes :id, :job_post_id, :changed_by, :changed_by_type, :from_status, :to_status,
             :changed_at, :reason, :metadata

  belongs_to :job_post
end
