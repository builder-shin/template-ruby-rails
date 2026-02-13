# frozen_string_literal: true

class ProfileFreelanceExperienceSerializer < ApplicationSerializer
  attributes :id, :profile_id, :company, :project_name, :project_start_date, :project_end_date,
             :role_and_contribution, :working_hours, :weekly_hours, :work_type, :recurring_contract,
             :created_at, :updated_at

  belongs_to :profile
end
