# frozen_string_literal: true

class CareerHubCommunityLeaderSerializer < ApplicationSerializer
  attributes :id, :name, :display_name, :bio, :quote, :avatar_url,
             :current_company, :current_position, :verification_badge,
             :status, :experiences, :social_links, :detailed_bio,
             :user_id, :created_at, :updated_at

  has_many :career_hub_communities
end
