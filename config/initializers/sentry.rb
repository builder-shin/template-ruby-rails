# frozen_string_literal: true

Sentry.init do |config|
  config.dsn = ENV["SENTRY_DSN"]
  config.breadcrumbs_logger = [:active_support_logger, :http_logger]
  config.traces_sample_rate = ENV.fetch("SENTRY_TRACES_SAMPLE_RATE", "0.1").to_f
  config.profiles_sample_rate = ENV.fetch("SENTRY_PROFILES_SAMPLE_RATE", "0.1").to_f
  config.send_default_pii = false
  config.environment = Rails.env

  # Skip sending in development/test
  config.enabled_environments = %w[production staging]

  # 민감한 필드만 선택적으로 필터링 (send_default_pii = false 와 함께 사용)
  sensitive_fields = %w[password token secret api_key credit_card ssn]
  config.before_send = lambda do |event, _hint|
    if event.request&.data.is_a?(Hash)
      event.request.data = event.request.data.each_with_object({}) do |(k, v), h|
        h[k] = sensitive_fields.any? { |sf| k.to_s.downcase.include?(sf) } ? "[FILTERED]" : v
      end
    end
    event
  end
end
