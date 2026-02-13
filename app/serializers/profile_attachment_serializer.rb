# frozen_string_literal: true

class ProfileAttachmentSerializer < ApplicationSerializer
  attributes :id, :profile_id, :original_file_name, :mime_type, :file_size,
             :sort_order, :created_at, :updated_at

  # Computed url attribute - uses Active Storage if available, else legacy url
  attribute :url do |object|
    object.computed_url
  end

  belongs_to :profile
end
