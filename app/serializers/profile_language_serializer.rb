# frozen_string_literal: true

class ProfileLanguageSerializer < ApplicationSerializer
  attributes :id, :profile_id, :language, :proficiency, :created_at, :updated_at

  belongs_to :profile
end
