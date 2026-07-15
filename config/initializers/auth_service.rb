# frozen_string_literal: true

auth_service_url = ENV["AUTH_SERVICE_URL"].presence
if auth_service_url.nil? && (Rails.env.development? || Rails.env.test?)
  auth_service_url = "http://localhost:3001"
end
raise "AUTH_SERVICE_URL must be configured outside development and test" if auth_service_url.nil?

Rails.application.config.x.auth_service = ActiveSupport::OrderedOptions.new
Rails.application.config.x.auth_service.url = auth_service_url
Rails.application.config.x.auth_service.cache_ttl = ENV.fetch("AUTH_SESSION_CACHE_TTL", 300).to_i
Rails.application.config.x.auth_service.timeout = ENV.fetch("AUTH_REQUEST_TIMEOUT", 5).to_i
