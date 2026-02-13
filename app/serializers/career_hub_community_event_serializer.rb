# frozen_string_literal: true

class CareerHubCommunityEventSerializer < ApplicationSerializer
  attributes :id, :title, :description, :status, :event_type,
             :community_id, :thumbnail_url,
             :start_at, :end_at, :location, :location_type, :meeting_link,
             :max_participants, :participants_count, :price,
             :registration_start_at, :registration_end_at,
             :publish_at, :tags,
             :review_notification_sent_at, :review_reminder_sent_at,
             :created_at, :updated_at

  belongs_to :career_hub_community, id_method_name: :community_id

  has_many :career_hub_community_event_participants
end
