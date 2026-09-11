# frozen_string_literal: true

require "swagger_helper"
require "json-schema"

RSpec.describe "OpenAPI re-audit" do
  let(:document) { JSON.parse(JSON.generate(RSpec.configuration.openapi_specs.fetch("v1/swagger.yaml"))) }

  it "declares the shared current-user validation response" do
    expect(document.dig("paths", "/api/v1/users/me", "get", "responses").keys.sort).to eq(%w[200 401 406 422 500])
  end

  it "validates a null category and null description using JSON Schema" do
    attributes = document.dig("components", "schemas", "ExampleAttributes")
    JSON::Validator.validate!(attributes, { title: "test", description: nil, status: "draft", score: 1, createdAt: "2026-01-01T00:00:00Z", updatedAt: "2026-01-01T00:00:00Z" })
    category = document.dig("components", "schemas", "CategoryDocument")
    JSON::Validator.validate!(category.merge("components" => document.fetch("components")), { data: nil, jsonapi: { version: "1.1" } })
  end

  it "documents allowed query parameters on the correct routes" do
    names = document.dig("paths", "/api/v1/examples", "get", "parameters").map { |entry| entry.fetch("name") }
    expect(names).to include("filter[score][gte]", "filter[category.id][isNull]", "page[after]", "sort", "include")
    expect(names).not_to include("fields[examples]")
  end
end
