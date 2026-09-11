# frozen_string_literal: true

require "rails_helper"
require "yaml"

RSpec.describe "API documentation", type: :request do
  it "serves the tracked OpenAPI document as valid YAML" do
    get "/api-docs/v1/swagger.yaml"

    expect(response).to have_http_status(:ok)
    expect(YAML.safe_load(response.body, aliases: true)).to include(
      "openapi" => "3.1.0",
      "paths" => include("/api/v1/examples", "/api/v1/categories", "/api/v1/tags")
    )
  end

  it "serves the canonical schema endpoint as OpenAPI JSON while retaining the YAML alias" do
    get "/api/schema"

    expect(response).to have_http_status(:ok)
    expect(response.media_type).to eq("application/json")
    expect(parsed_body).to include(
      "openapi" => "3.1.0",
      "paths" => include("/api/v1/examples", "/api/v1/categories", "/api/v1/tags")
    )
  end
end
