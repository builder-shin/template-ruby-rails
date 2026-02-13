# frozen_string_literal: true

class ProfileEducationSerializer < ApplicationSerializer
  attributes :id, :profile_id, :school, :major, :minor, :double_major, :education_level,
             :status, :enrollment_date, :graduation_date, :created_at, :updated_at

  belongs_to :profile
end
