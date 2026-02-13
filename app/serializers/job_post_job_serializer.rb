# frozen_string_literal: true

class JobPostJobSerializer < ApplicationSerializer
  attributes :job_post_id, :job_id

  belongs_to :job_post
  belongs_to :job
end
