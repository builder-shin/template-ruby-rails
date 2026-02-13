# frozen_string_literal: true

Rails.application.config.x.auth_service = ActiveSupport::OrderedOptions.new
Rails.application.config.x.auth_service.url = ENV.fetch("AUTH_SERVICE_URL", "http://localhost:3001")
Rails.application.config.x.auth_service.cache_ttl = ENV.fetch("AUTH_SESSION_CACHE_TTL", 300).to_i
Rails.application.config.x.auth_service.timeout = ENV.fetch("AUTH_REQUEST_TIMEOUT", 5).to_i
