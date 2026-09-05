# frozen_string_literal: true

require "rails_helper"
require "yaml"

RSpec.describe "API documentation", type: :request do
  it "serves the tracked OpenAPI document as valid YAML" do
    get "/api-docs/v1/swagger.yaml"

    expect(response).to have_http_status(:ok)
    expect(YAML.safe_load(response.body, aliases: true)).to include(
      "openapi" => "3.0.1",
      "paths" => include("/api/v1/examples", "/api/v1/categories", "/api/v1/tags")
    )
  end
end
