# frozen_string_literal: true

class FeaturedProfileSerializer < ApplicationSerializer
  attributes :id, :profile_id, :display_order, :is_active,
             :created_at, :updated_at

  belongs_to :profile
end
