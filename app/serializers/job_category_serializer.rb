# frozen_string_literal: true

class JobCategorySerializer < ApplicationSerializer
  attributes :id, :name, :created_at, :updated_at

  has_many :highlight_references
  has_many :application_context_references
  has_many :jobs
  has_many :practical_strength_references
  has_many :profiles
  has_many :job_post_categories
  has_many :job_posts
end
