# frozen_string_literal: true

require "swagger_helper"
require "open3"
require "yaml"

RSpec.describe "Swagger contract" do
  let(:openapi) { RSpec.configuration.openapi_specs.fetch("v1/swagger.yaml") }
  let(:schemas) { openapi.dig(:components, :schemas) }

  def normalized(value)
    JSON.parse(JSON.generate(value))
  end

  def response_schema_ref(path, method, status)
    openapi.dig(
      :paths,
      path,
      method,
      :responses,
      status,
      :content,
      "application/vnd.api+json",
      :schema,
      "$ref"
    )
  end

  def request_schema_ref(path, method)
    openapi.dig(
      :paths,
      path,
      method,
      :requestBody,
      :content,
      "application/vnd.api+json",
      :schema,
      "$ref"
    )
  end

  it "uses the local port and exact document schema for each public read path" do
    expect(openapi.fetch(:servers)).to eq([ { url: "http://localhost:4000" } ])
    expect(response_schema_ref("/api/v1/examples", :get, "200"))
      .to eq("#/components/schemas/ExampleCollectionDocument")
    expect(response_schema_ref("/api/v1/examples/{id}", :get, "200"))
      .to eq("#/components/schemas/ExampleDocument")
    expect(response_schema_ref("/api/v1/examples/{id}", :put, "200"))
      .to eq("#/components/schemas/ExampleDocument")
    expect(response_schema_ref("/api/v1/examples/{id}", :put, "201"))
      .to eq("#/components/schemas/ExampleDocument")
    expect(response_schema_ref("/api/v1/examples/{id}/relationships/category", :get, "200"))
      .to eq("#/components/schemas/CategoryRelationshipDocument")
    expect(response_schema_ref("/api/v1/examples/{id}/category", :get, "200"))
      .to eq("#/components/schemas/CategoryDocument")
    expect(response_schema_ref("/api/v1/examples/{id}/relationships/tags", :get, "200"))
      .to eq("#/components/schemas/TagsRelationshipDocument")
    expect(response_schema_ref("/api/v1/examples/{id}/tags", :get, "200"))
      .to eq("#/components/schemas/TagCollectionDocument")
    expect(response_schema_ref("/api/v1/categories", :get, "200"))
      .to eq("#/components/schemas/ExampleCategoryCollectionDocument")
    expect(response_schema_ref("/api/v1/categories/{id}", :get, "200"))
      .to eq("#/components/schemas/ExampleCategoryDocument")
    expect(response_schema_ref("/api/v1/tags", :get, "200"))
      .to eq("#/components/schemas/ExampleTagCollectionDocument")
    expect(response_schema_ref("/api/v1/tags/{id}", :get, "200"))
      .to eq("#/components/schemas/ExampleTagDocument")
  end

  it "describes collection, linkage, and related data with different JSON:API shapes" do
    expect(schemas.dig(:ExampleCollectionDocument, :properties, :data, :type)).to eq("array")
    expect(schemas.dig(:CategoryRelationshipDocument, :properties, :data, :allOf, 0, "$ref"))
      .to eq("#/components/schemas/ExampleCategoryIdentifier")
    expect(schemas.dig(:CategoryRelationshipDocument, :properties, :data, :nullable)).to be(true)
    expect(schemas.dig(:TagsRelationshipDocument, :properties, :data, :items, "$ref"))
      .to eq("#/components/schemas/ExampleTagIdentifier")
    expect(schemas.dig(:CategoryDocument, :properties, :data, :allOf, 0, "$ref"))
      .to eq("#/components/schemas/ExampleCategoryResource")
    expect(schemas.dig(:TagCollectionDocument, :properties, :data, :items, "$ref"))
      .to eq("#/components/schemas/ExampleTagResource")
    expect(schemas.dig(:TagCollectionDocument, :required)).to eq(%w[data links])
    expect(schemas.dig(:TagCollectionDocument, :properties, :meta, :required)).to eq([ "totalCount" ])
  end

  it "uses distinct create, patch, and replace schemas for write semantics" do
    expect(request_schema_ref("/api/v1/examples", :post))
      .to eq("#/components/schemas/ExampleCreateDocument")
    expect(request_schema_ref("/api/v1/examples/{id}", :patch))
      .to eq("#/components/schemas/ExamplePatchDocument")
    expect(request_schema_ref("/api/v1/examples/{id}", :put))
      .to eq("#/components/schemas/ExampleReplaceDocument")

    expect(schemas.dig(:ExampleCreateAttributes, :required)).to eq([ "title" ])
    expect(schemas.dig(:ExampleReplaceAttributes, :required)).to eq([ "title" ])
    expect(schemas.dig(:ExamplePatchDocument, :properties, :data, :anyOf)).to eq(
      [ { required: [ "attributes" ] }, { required: [ "relationships" ] } ]
    )
  end

  it "ships a generated Swagger document and verifies it in CI and the production image" do
    swagger_path = Rails.root.join("swagger/v1/swagger.yaml")
    _stdout, _stderr, ignored_status = Open3.capture3(
      "git", "check-ignore", swagger_path.to_s, chdir: Rails.root.to_s
    )
    workflow = Rails.root.join(".github/workflows/ci.yml").read

    expect(swagger_path).to exist
    expect(ignored_status).not_to be_success
    expect(YAML.safe_load_file(swagger_path, aliases: true)).to eq(normalized(openapi))
    expect(workflow).to include(
      "rswag:specs:swaggerize",
      "git diff --exit-code -- swagger/v1/swagger.yaml",
      "test -f /app/swagger/v1/swagger.yaml"
    )
  end
end
