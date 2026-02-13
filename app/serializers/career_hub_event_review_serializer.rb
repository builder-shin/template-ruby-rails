# frozen_string_literal: true

class CareerHubEventReviewSerializer < ApplicationSerializer
  attributes :id, :event_id, :user_id, :content, :rating,
             :deleted_at, :created_at, :updated_at

  belongs_to :career_hub_community_event, id_method_name: :event_id
end
