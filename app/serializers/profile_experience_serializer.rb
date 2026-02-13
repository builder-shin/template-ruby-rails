# frozen_string_literal: true

class ProfileExperienceSerializer < ApplicationSerializer
  attributes :id, :profile_id, :company, :position, :start_date, :end_date, :current,
             :is_featured, :work_type, :created_at, :updated_at

  belongs_to :profile
end
