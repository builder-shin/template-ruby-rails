# frozen_string_literal: true

class ProfileAttachment < ApplicationRecord
  # Active Storage attachment
  has_one_attached :file

  # Associations
  belongs_to :profile

  # Constants
  ALLOWED_CONTENT_TYPES = %w[
    application/pdf
    application/msword
    application/vnd.openxmlformats-officedocument.wordprocessingml.document
    image/jpeg
    image/png
    image/gif
    image/webp
  ].freeze

  MAX_FILE_SIZE = 10.megabytes

  # Validations
  validates :profile_id, presence: true
  validates :original_file_name, presence: true, length: { maximum: 255 }
  validates :sort_order, numericality: { only_integer: true, greater_than_or_equal_to: 0 }
  validates :mime_type, length: { maximum: 100 }, allow_nil: true
  validates :file_size, numericality: { only_integer: true, greater_than: 0 }, allow_nil: true
  validate :file_or_url_present

  # Scopes
  default_scope { order(sort_order: :asc) }

  # Computed URL - Active Storage takes priority, fallback to legacy url field
  def computed_url
    if file.attached?
      Rails.application.routes.url_helpers.url_for(file)
    else
      url
    end
  rescue ArgumentError
    # Fallback if default_url_options not configured
    file.attached? ? file.url : url
  end

  private

  def file_or_url_present
    return if file.attached? || url.present?

    errors.add(:base, "파일 또는 URL이 필요합니다")
  end
end
