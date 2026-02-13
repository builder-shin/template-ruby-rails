# frozen_string_literal: true

class Job < ApplicationRecord
  # Associations
  belongs_to :job_category
  has_many :profile_jobs, dependent: :restrict_with_error
  has_many :job_post_jobs, dependent: :destroy
  has_many :job_posts, through: :job_post_jobs

  # Validations
  validates :job_category_id, presence: true
  validates :name, presence: true
end
