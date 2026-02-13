# frozen_string_literal: true

class CareerHubCommunityMemberSerializer < ApplicationSerializer
  attributes :id, :community_id, :user_id, :role, :status, :answers,
             :joined_at, :created_at, :updated_at

  belongs_to :career_hub_community, id_method_name: :community_id
end
