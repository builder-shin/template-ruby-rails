# frozen_string_literal: true

class CareerHubCommunitySerializer < ApplicationSerializer
  attributes :id, :title, :description, :status, :join_policy,
             :category_id, :subcategory_id, :leader_id,
             :thumbnail_url, :slug, :schedule, :duration,
             :max_participants, :participants_count,
             :intro_content, :questions, :tags,
             :approved_at, :withdrawn_at,
             :created_at, :updated_at

  belongs_to :career_hub_category, id_method_name: :category_id
  belongs_to :career_hub_subcategory, serializer: :career_hub_category, id_method_name: :subcategory_id
  belongs_to :career_hub_community_leader, id_method_name: :leader_id

  has_many :career_hub_community_events
  has_many :career_hub_community_feeds
end
