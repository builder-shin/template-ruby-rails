# frozen_string_literal: true

class JobPostLanguageSerializer < ApplicationSerializer
  attributes :id, :job_post_id, :language, :proficiency, :created_at, :updated_at

  belongs_to :job_post
end
