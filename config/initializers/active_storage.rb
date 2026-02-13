# frozen_string_literal: true

# Active Storage configuration
Rails.application.config.active_storage.service_urls_expire_in = 1.hour

# Content types allowed for direct upload
Rails.application.config.active_storage.web_image_content_types = %w[
  image/png
  image/jpeg
  image/gif
  image/webp
]

# Direct upload configuration
Rails.application.config.active_storage.resolve_model_to_route = :rails_storage_proxy
