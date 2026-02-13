class JobCategory < ApplicationRecord
  # Associations
  has_many :highlight_references, dependent: :destroy
  has_many :application_context_references, dependent: :destroy
  has_many :jobs, dependent: :destroy
  has_many :practical_strength_references, dependent: :destroy
  has_many :profiles, dependent: :destroy
  has_many :job_post_categories, dependent: :destroy
  has_many :job_posts, through: :job_post_categories

  # Validations
  validates :name, presence: true, uniqueness: true
end
