# frozen_string_literal: true

require "sendgrid-ruby"

Rails.application.config.x.sendgrid = ActiveSupport::OrderedOptions.new.tap do |config|
  config.api_key = ENV.fetch("SENDGRID_API_KEY", nil)
  config.from_email = ENV.fetch("SENDGRID_FROM_EMAIL", "noreply@flexwork.kr")
  config.from_name = ENV.fetch("SENDGRID_FROM_NAME", "Flexwork")
end
