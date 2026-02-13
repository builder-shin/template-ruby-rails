# frozen_string_literal: true

class JobSerializer < ApplicationSerializer
  attributes :id, :job_category_id, :name, :created_at, :updated_at

  belongs_to :job_category
  has_many :profile_jobs
  has_many :job_post_jobs
  has_many :job_posts
end
