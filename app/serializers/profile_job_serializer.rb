# frozen_string_literal: true

class ProfileJobSerializer < ApplicationSerializer
  attributes :profile_id, :job_id

  belongs_to :profile
  belongs_to :job
end
