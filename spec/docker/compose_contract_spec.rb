# frozen_string_literal: true

require "rails_helper"
require "yaml"

RSpec.describe "Development container contract" do
  let(:compose_path) { Rails.root.join("docker-compose.yml") }
  let(:dockerfile_path) { Rails.root.join("Dockerfile") }
  let(:dockerignore_path) { Rails.root.join(".dockerignore") }

  def read_yaml(path)
    expect(path).to exist
    YAML.safe_load_file(path, aliases: true)
  end

  def compose
    @compose ||= read_yaml(compose_path)
  end

  def services
    compose.fetch("services")
  end

  def mapping(name)
    read_yaml(Rails.root.join("docker/wiremock/mappings/#{name}.json"))
  end

  it "defines exactly the development services and named data volumes" do
    expect(services.keys).to contain_exactly("db", "redis", "auth-stub", "migrate", "api", "worker")
    expect(compose.fetch("volumes").keys).to contain_exactly("postgres_data", "redis_data")
  end

  it "pins PostgreSQL 18 and gives PostgreSQL and Redis persistent health-checked storage" do
    db = services.fetch("db")
    redis = services.fetch("redis")

    expect(db.fetch("image")).to eq("postgres:18")
    expect(db.dig("healthcheck", "test").join(" ")).to include("pg_isready")
    expect(db.fetch("volumes")).to include(a_string_starting_with("postgres_data:"))
    expect(redis.fetch("image")).to start_with("redis:")
    expect(redis.dig("healthcheck", "test").join(" ")).to include("redis-cli", "ping")
    expect(redis.fetch("volumes")).to include("redis_data:/data")
  end

  it "builds every Rails service from the development target with the shared development environment" do
    %w[migrate api worker].each do |service_name|
      service = services.fetch(service_name)
      environment = service.fetch("environment")

      expect(service.fetch("build")).to eq("context" => ".", "target" => "development")
      expect(environment).to include(
        "RAILS_ENV" => "development",
        "DATABASE_HOST" => "db",
        "DATABASE_PORT" => "5432",
        "DEV_DATABASE_USERNAME" => "postgres",
        "DEV_DATABASE_PASSWORD" => "postgres",
        "DEV_DATABASE_NAME" => "template_development",
        "AUTH_SERVICE_URL" => "http://auth-stub:8080",
        "ACTIVE_JOB_QUEUE_ADAPTER" => "sidekiq",
        "PORT" => "4000"
      )
    end

    expect(services.dig("api", "ports")).to eq([ "4000:4000" ])
  end

  it "assigns migrations only to migrate and gates API and worker startup correctly" do
    migrate = services.fetch("migrate")
    api = services.fetch("api")
    worker = services.fetch("worker")

    expect(migrate.fetch("command")).to eq("bin/rails db:prepare")
    expect(api.fetch("command")).to eq("bundle exec puma -C config/puma.rb")
    expect(worker.fetch("command")).to eq("bundle exec sidekiq")
    expect(api.fetch("command")).not_to match(/db:(?:migrate|prepare)/)
    expect(worker.fetch("command")).not_to match(/db:(?:migrate|prepare)/)
    expect(api.fetch("depends_on")).to include(
      "migrate" => { "condition" => "service_completed_successfully" }
    )
    expect(api.fetch("depends_on")).not_to have_key("redis")
    expect(worker.fetch("depends_on")).to eq(
      "migrate" => { "condition" => "service_completed_successfully" },
      "redis" => { "condition" => "service_healthy" }
    )
  end

  it "uses the container Redis endpoint without making API readiness depend on Redis" do
    expect(services.dig("api", "environment", "REDIS_URL")).to eq("redis://redis:6379/0")
    expect(services.dig("worker", "environment", "REDIS_URL")).to eq("redis://redis:6379/0")

    dockerfile = dockerfile_path.read
    expect(dockerfile).to include("/health/ready")
    expect(dockerfile).not_to include("/health/live")
  end

  it "matches only the development session cookie in the successful Auth stub mapping" do
    success = mapping("auth-me-success")
    unauthorized = mapping("auth-me-unauthorized")

    expect(success).to include("priority" => 1)
    expect(success.fetch("request")).to eq(
      "method" => "GET",
      "urlPath" => "/api/auth/me",
      "headers" => { "Cookie" => { "equalTo" => "session_web=dev-session" } }
    )
    expect(success.dig("response", "status")).to eq(200)
    expect(JSON.parse(success.dig("response", "jsonBody").to_json)).to include(
      "success" => true,
      "data" => include("member_status" => "active")
    )

    expect(unauthorized).to include("priority" => 10)
    expect(unauthorized.fetch("request")).to eq(
      "method" => "GET",
      "urlPath" => "/api/auth/me"
    )
    expect(unauthorized.dig("response", "status")).to eq(401)
  end

  it "keeps the Auth stub out of the final production image and runs Puma only" do
    dockerfile = dockerfile_path.read
    dockerignore = dockerignore_path.readlines(chomp: true)

    expect(dockerfile.scan(/^FROM /).length).to be >= 4
    expect(dockerfile).to match(/^FROM .+ AS base$/)
    expect(dockerfile).to match(/^FROM base AS bundle$/)
    expect(dockerfile).to match(/^FROM bundle AS development$/)
    expect(dockerfile).to include('BUNDLE_WITHOUT="development:test"')
    expect(dockerfile.lines.grep(/^CMD /).last.strip)
      .to eq('CMD ["bundle", "exec", "puma", "-C", "config/puma.rb"]')
    expect(dockerfile).not_to include("docker/wiremock")
    expect(dockerignore).to include("/docker/wiremock")
  end
end
