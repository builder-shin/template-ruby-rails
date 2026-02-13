# frozen_string_literal: true

class ProfileHighlightSerializer < ApplicationSerializer
  attributes :id, :profile_id, :title, :after, :details, :before, :action,
             :created_at, :updated_at

  belongs_to :profile
end
