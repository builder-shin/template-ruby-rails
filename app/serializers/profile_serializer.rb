# frozen_string_literal: true

class ProfileSerializer < ApplicationSerializer
  attributes :id, :user_id, :name, :phone, :email_public, :profile_image, :introduction,
             :about, :job_category_id, :nationality_id, :domicile, :job_seeking_status,
             :start_work, :expertise, :practical_strength, :collaboration_and_communication,
             :problem_solving_and_execution, :total_years_of_experience, :overall_completeness,
             :required_completeness, :weight, :skills, :employment_type, :work_type,
             :created_at, :updated_at

  belongs_to :user, serializer: Auth::UserSerializer
  belongs_to :job_category
  belongs_to :nationality, serializer: :country

  has_many :profile_highlights
  has_many :profile_jobs
  has_many :jobs
  has_many :profile_languages
  has_many :profile_links
  has_many :profile_projects
  has_many :profile_experiences
  has_many :profile_freelance_experiences
  has_many :profile_educations
  has_many :profile_attachments
  has_many :featured_profiles
  has_many :job_applications
end
