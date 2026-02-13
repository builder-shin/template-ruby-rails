# frozen_string_literal: true

class ProfileLinkSerializer < ApplicationSerializer
  attributes :id, :profile_id, :url, :created_at, :updated_at

  belongs_to :profile
end
