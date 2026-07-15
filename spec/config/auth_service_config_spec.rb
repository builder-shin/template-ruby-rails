# frozen_string_literal: true

require "rails_helper"

RSpec.describe "Auth service configuration" do
  INITIALIZER = Rails.root.join("config/initializers/auth_service.rb")
  ENVIRONMENT_KEYS = %w[AUTH_SERVICE_URL AUTH_SESSION_CACHE_TTL AUTH_REQUEST_TIMEOUT].freeze

  around do |example|
    original_environment = ENVIRONMENT_KEYS.to_h { |key| [ key, ENV[key] ] }
    original_config = Rails.application.config.x.auth_service

    example.run
  ensure
    original_environment.each do |key, value|
      value.nil? ? ENV.delete(key) : ENV[key] = value
    end
    Rails.application.config.x.auth_service = original_config
  end

  def load_auth_initializer(environment:, url: :missing)
    allow(Rails).to receive(:env).and_return(ActiveSupport::EnvironmentInquirer.new(environment))
    url == :missing ? ENV.delete("AUTH_SERVICE_URL") : ENV["AUTH_SERVICE_URL"] = url

    load INITIALIZER
    Rails.application.config.x.auth_service
  end

  it "production에서 AUTH_SERVICE_URL이 누락되면 즉시 실패한다" do
    expect { load_auth_initializer(environment: "production") }
      .to raise_error(/AUTH_SERVICE_URL/)
  end

  it "production에서 AUTH_SERVICE_URL이 blank이면 즉시 실패한다" do
    [ "", "  " ].each do |blank_url|
      expect { load_auth_initializer(environment: "production", url: blank_url) }
        .to raise_error(/AUTH_SERVICE_URL/)
    end
  end

  it "development와 test에서만 localhost fallback을 사용한다" do
    %w[development test].each do |environment|
      config = load_auth_initializer(environment: environment)

      expect(config.url).to eq("http://localhost:3001")
    end
  end
end
