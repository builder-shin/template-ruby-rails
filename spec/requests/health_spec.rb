# frozen_string_literal: true

require "rails_helper"

RSpec.describe "Health endpoints", type: :request do
  let(:connection) { double("database connection") }

  it "reports liveness without touching the database or negotiating JSON:API" do
    expect(ActiveRecord::Base).not_to receive(:connection)

    get "/health/live", headers: { "ACCEPT" => "application/xml" }

    expect(response).to have_http_status(:ok)
  end

  it "reports readiness after a successful SELECT 1" do
    expect(ActiveRecord::Base).to receive(:connection).once.and_return(connection)
    expect(connection).to receive(:select_value).with("SELECT 1").once.and_return(1)

    get "/health/ready", headers: { "ACCEPT" => "application/xml" }

    expect(response).to have_http_status(:ok)
  end

  [
    ActiveRecord::StatementInvalid.new("SELECT 1 FROM secret_table"),
    PG::ConnectionBad.new("database connection secret")
  ].each do |database_error|
    it "returns a safe 503 for #{database_error.class}" do
      allow(ActiveRecord::Base).to receive(:connection).and_return(connection)
      allow(connection).to receive(:select_value).with("SELECT 1").and_raise(database_error)

      get "/health/ready"

      expect(response).to have_http_status(:service_unavailable)
      expect(response.body).not_to include(
        "SELECT 1",
        "secret_table",
        "PG::ConnectionBad",
        "database connection secret"
      )
    end
  end

  it "leaves programming errors to the global safe 500 handler" do
    allow(ActiveRecord::Base).to receive(:connection).and_return(connection)
    allow(connection).to receive(:select_value).with("SELECT 1")
      .and_raise(NoMethodError, "undefined health implementation secret")

    get "/health/ready"

    expect(response).to have_http_status(:internal_server_error)
    expect(response.headers.fetch("Content-Type")).to eq(JsonapiRequestHelper::JSONAPI_MEDIA_TYPE)
    expect(parsed_body.dig("errors", 0, "code")).to eq("INTERNAL_SERVER_ERROR")
    expect(response.body).not_to include("NoMethodError", "undefined health implementation secret")
  end
end
