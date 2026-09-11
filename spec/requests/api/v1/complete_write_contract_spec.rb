# frozen_string_literal: true

require "rails_helper"

RSpec.describe "Complete write document contract", type: :request do
  before { mock_bearer_user }

  def submit(body, method: :post, path: "/api/v1/examples")
    public_send(method, path, params: body.to_json, headers: jsonapi_headers.merge(auth_bearer_headers))
  end

  def valid
    { type: "examples", attributes: { title: "Write", status: "active", score: 42 } }
  end

  def expect_pointers(*pointers)
    expect(response.status).to eq(422), response.body
    expect(parsed_body.fetch("errors").map { |error| error.fetch("code") }.uniq).to eq([ "VALIDATION_ERROR" ])
    expect(parsed_body.fetch("errors").map { |error| error.dig("source", "pointer") }.sort).to eq(pointers.sort)
  end

  { title: [ 123, true, nil, "" ], description: [ 123, false, [], {} ], score: [ "42", true, nil, 4.2, -1, 101 ], status: [ 0, true, nil, "other" ] }.each do |field, values|
    values.each do |value|
      it "rejects #{field}=#{value.inspect} before ORM coercion" do
        data = valid
        data[:attributes][field] = value
        submit({ data: data })
        expect_pointers("/data/attributes/#{field}")
      end
    end
  end

  [ 42, 42.0, 4.2e1 ].each do |score|
    it "accepts integral JSON number #{score.inspect} and a blank title" do
      data = valid
      data[:attributes].merge!(score: score, title: " ")
      submit({ data: data })
      expect(response.status).to eq(201), response.body
      expect(parsed_body.dig("data", "attributes", "score")).to eq(42)
    end
  end

  %i[bogus meta links jsonapi included].each do |member|
    it "rejects top #{member}" do
      submit({ data: valid, member => {} })
      expect_pointers("/#{member}")
    end
  end

  it "aggregates missing type id and attributes" do
    submit({ data: { attributes: {} } }, method: :put, path: "/api/v1/examples/#{SecureRandom.uuid}")
    expect_pointers("/data/type", "/data/id", "/data/attributes/title", "/data/attributes/status", "/data/attributes/score")
  end

  it "rejects embedded relationship meta but permits identifier meta" do
    data = valid.merge(relationships: { category: { data: nil, meta: {} } })
    submit({ data: data })
    expect_pointers("/data/relationships/category/meta")
    category = create(:example_category)
    data[:relationships] = { category: { data: { type: "exampleCategories", id: category.id, meta: {} } } }
    submit({ data: data })
    expect(response.status).to eq(201), response.body
  end

  it "includes an empty included array on explicit empty include and has no top self" do
    example = create(:example)
    get "/api/v1/examples/#{example.id}?include=", headers: jsonapi_headers
    expect(response.status).to eq(200)
    expect(parsed_body["included"]).to eq([])
    expect(parsed_body).not_to have_key("links")
  end

  it "ignores malformed GET bodies" do
    environment = Rack::MockRequest.env_for("/api/v1/examples", method: "GET", input: "{broken",
      "CONTENT_TYPE" => JsonapiRequestHelper::JSONAPI_MEDIA_TYPE,
      "HTTP_ACCEPT" => JsonapiRequestHelper::JSONAPI_MEDIA_TYPE)
    status, _headers, body = Rails.application.call(environment)
    expect(status).to eq(200), body.each.to_a.join
    body.close if body.respond_to?(:close)
  end

  it "rejects malformed write JSON with 422 before Accept negotiation" do
    post "/api/v1/examples", params: "{broken", headers: jsonapi_headers.merge("Accept" => "text/html")
    expect(response.status).to eq(422), response.body
    expect(parsed_body.fetch("errors").first.fetch("code")).to eq("VALIDATION_ERROR")
  end

  it "accepts Python UUID URL forms and matches document ids literally" do
    example = create(:example)
    [ example.id.delete("-"), "{#{example.id}}", "urn:uuid:#{example.id}" ].each do |id|
      get "/api/v1/examples/#{ERB::Util.url_encode(id)}", headers: jsonapi_headers
      expect(response.status).to eq(200), response.body
      expect(parsed_body.dig("data", "id")).to eq(example.id)
    end
    submit({ data: { type: "examples", id: example.id, attributes: {} } },
      method: :patch, path: "/api/v1/examples/#{example.id.delete('-')}")
    expect(response.status).to eq(409), response.body
    expect(parsed_body.dig("errors", 0, "code")).to eq("ID_MISMATCH")
  end

  it "accepts compact UUIDs for reference resources" do
    category = create(:example_category)
    tag = create(:example_tag)
    [ [ "categories", category.id ], [ "tags", tag.id ] ].each do |collection, id|
      get "/api/v1/#{collection}/#{id.delete('-')}", headers: jsonapi_headers
      expect(response.status).to eq(200), response.body
      expect(parsed_body.dig("data", "id")).to eq(id)
    end
  end
end
