# frozen_string_literal: true

class ProcessImageVariantsJob < ApplicationJob
  queue_as :default

  IMAGE_CONTENT_TYPES = %w[image/jpeg image/png image/gif image/webp].freeze

  VARIANTS = {
    thumbnail: { resize_to_fill: [ 80, 80 ] },
    medium: { resize_to_fill: [ 200, 200 ] },
    large: { resize_to_fill: [ 400, 400 ] }
  }.freeze

  def perform(blob_id)
    blob = ActiveStorage::Blob.find_by(id: blob_id)
    return unless blob
    return unless IMAGE_CONTENT_TYPES.include?(blob.content_type)

    VARIANTS.each do |name, transforms|
      begin
        blob.variant(transforms).processed
        Rails.logger.info("[ProcessImageVariantsJob] #{name} variant generated for blob #{blob_id}")
      rescue => e
        Rails.logger.warn("[ProcessImageVariantsJob] Failed to generate #{name} variant for blob #{blob_id}: #{e.message}")
      end
    end
  end
end
