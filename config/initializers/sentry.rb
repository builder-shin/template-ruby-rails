# frozen_string_literal: true

Sentry.init do |config|
  config.dsn = ENV["SENTRY_DSN"]
  config.breadcrumbs_logger = [ :active_support_logger, :http_logger ]
  config.traces_sample_rate = ENV.fetch("SENTRY_TRACES_SAMPLE_RATE", "0.1").to_f
  config.profiles_sample_rate = ENV.fetch("SENTRY_PROFILES_SAMPLE_RATE", "0.1").to_f
  config.send_default_pii = false
  config.environment = Rails.env

  # Skip sending in development/test
  config.enabled_environments = %w[production staging]

  # Filter sensitive parameters
  config.before_send = lambda do |event, _hint|
    event.request.data = "[FILTERED]" if event.request&.data
    event
  end
end
