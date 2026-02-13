# frozen_string_literal: true

class ProfileProjectSerializer < ApplicationSerializer
  attributes :id, :profile_id, :company, :project_name, :project_start_date, :project_end_date,
             :background_or_goal, :role, :tools, :result, :working_hours, :weekly_hours,
             :created_at, :updated_at

  belongs_to :profile
end
