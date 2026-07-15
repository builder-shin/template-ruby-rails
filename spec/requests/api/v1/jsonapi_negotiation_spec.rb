# frozen_string_literal: true

require "rails_helper"

RSpec.describe "JSON:API media type negotiation", type: :request do
  let(:unknown_path) { "/api/v1/task-five-missing" }

  def expect_error(status:, code:, parameter:)
    expect(response).to have_http_status(status)
    expect(response.media_type).to eq(JsonapiRequestHelper::JSONAPI_MEDIA_TYPE)
    expect(parsed_body.fetch("errors").first).to include(
      "status" => status.to_s,
      "code" => code,
      "source" => { "parameter" => parameter }
    )
  end

  it "rejects an Accept header that cannot receive JSON:API" do
    get unknown_path, headers: { "ACCEPT" => "application/json" }

    expect_error(status: 406, code: "NOT_ACCEPTABLE", parameter: "Accept")
  end

  it "rejects unsupported JSON:API Accept parameters" do
    get unknown_path, headers: { "ACCEPT" => "application/vnd.api+json; charset=utf-8" }

    expect_error(status: 406, code: "NOT_ACCEPTABLE", parameter: "Accept")
  end

  it "accepts unparameterized JSON:API and ext/profile parameters" do
    compatible_accepts = [
      "application/vnd.api+json",
      " Application/Vnd.Api+Json ",
      'application/vnd.api+json;ext="https://jsonapi.org/ext/version"',
      'application/vnd.api+json;profile="https://example.com/resource-timestamps"',
      'application/vnd.api+json;ext="https://jsonapi.org/ext/version";profile="https://example.com/profile"',
      'application/vnd.api+json; ext="https://jsonapi.org/ext/version"; profile="https://example.com/profile"',
      "text/plain;q=0.1, application/vnd.api+json;q=0.8",
      'application/json;note="comma,inside", application/vnd.api+json;q=0.7',
      "application/*",
      "*/*"
    ]

    compatible_accepts.each do |accept|
      get unknown_path, headers: { "ACCEPT" => accept }

      expect(response).to have_http_status(:not_found), "expected #{accept.inspect} to be compatible"
      expect(parsed_body.dig("errors", 0, "code")).to eq("RESOURCE_NOT_FOUND")
    end
  end

  it "rejects invalid quality values and a more-specific JSON:API exclusion" do
    incompatible_accepts = [
      "application/vnd.api+json;q=0",
      "application/vnd.api+json;q=invalid",
      'application/vnd.api+json;q="0.7"',
      "application/vnd.api+json;q = 0.7",
      "application/vnd.api+json;q=0.1234",
      "application/vnd.api+json;q=0.5;q=0.8",
      "application/vnd.api+json;q=0, application/*;q=1, */*;q=1",
      "application/vnd.api+json;charset=utf-8, */*;q=1"
    ]

    incompatible_accepts.each do |accept|
      get unknown_path, headers: { "ACCEPT" => accept }

      expect_error(status: 406, code: "NOT_ACCEPTABLE", parameter: "Accept")
    end
  end

  it "accepts a compatible range when another Accept range is incompatible" do
    get unknown_path,
        headers: { "ACCEPT" => "application/json, application/vnd.api+json;profile=example" }

    expect(response).to have_http_status(:not_found)
    expect(parsed_body.dig("errors", 0, "code")).to eq("RESOURCE_NOT_FOUND")
  end

  it "requires JSON:API Content-Type only when a write request has a body" do
    %i[post put patch delete].each do |method|
      public_send(method, unknown_path, headers: { "ACCEPT" => JsonapiRequestHelper::JSONAPI_MEDIA_TYPE })

      expect(response).to have_http_status(:not_found)
      expect(parsed_body.dig("errors", 0, "code")).to eq("RESOURCE_NOT_FOUND")
    end

    post unknown_path,
         params: { data: {} }.to_json,
         headers: {
           "ACCEPT" => JsonapiRequestHelper::JSONAPI_MEDIA_TYPE,
           "CONTENT_TYPE" => "application/json"
         }

    expect_error(status: 415, code: "UNSUPPORTED_MEDIA_TYPE", parameter: "Content-Type")
  end

  it "accepts ext/profile Content-Type parameters and rejects other parameters" do
    post unknown_path,
         params: { data: {} }.to_json,
         headers: {
           "ACCEPT" => JsonapiRequestHelper::JSONAPI_MEDIA_TYPE,
           "CONTENT_TYPE" => 'application/vnd.api+json;ext="https://jsonapi.org/ext/version";profile=example'
         }

    expect(response).to have_http_status(:not_found)
    expect(parsed_body.dig("errors", 0, "code")).to eq("RESOURCE_NOT_FOUND")

    post unknown_path,
         params: { data: {} }.to_json,
         headers: {
           "ACCEPT" => JsonapiRequestHelper::JSONAPI_MEDIA_TYPE,
           "CONTENT_TYPE" => "application/vnd.api+json; charset=utf-8"
         }

    expect_error(status: 415, code: "UNSUPPORTED_MEDIA_TYPE", parameter: "Content-Type")
  end

  it "accepts optional whitespace before allowed Content-Type parameters" do
    post unknown_path,
         params: { data: {} }.to_json,
         headers: {
           "ACCEPT" => JsonapiRequestHelper::JSONAPI_MEDIA_TYPE,
           "CONTENT_TYPE" => ' Application/Vnd.Api+Json ; ext="https://jsonapi.org/ext/version" '
         }

    expect(response).to have_http_status(:not_found)
    expect(parsed_body.dig("errors", 0, "code")).to eq("RESOURCE_NOT_FOUND")
  end

  it "maps malformed JSON to INVALID_JSONAPI_DOCUMENT" do
    post unknown_path,
         params: '{"data":',
         headers: jsonapi_headers

    expect(response).to have_http_status(:bad_request)
    expect(response.media_type).to eq(JsonapiRequestHelper::JSONAPI_MEDIA_TYPE)
    expect(parsed_body.dig("errors", 0, "code")).to eq("INVALID_JSONAPI_DOCUMENT")
  end

  it "rejects a JSON:API request document without data" do
    post unknown_path,
         params: { meta: { requestId: "safe" } }.to_json,
         headers: jsonapi_headers

    expect(response).to have_http_status(:bad_request)
    expect(response.media_type).to eq(JsonapiRequestHelper::JSONAPI_MEDIA_TYPE)
    expect(parsed_body.dig("errors", 0)).to include(
      "status" => "400",
      "code" => "INVALID_JSONAPI_DOCUMENT",
      "source" => { "pointer" => "/data" }
    )
  end
end
