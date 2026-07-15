# frozen_string_literal: true

require "rails_helper"

RSpec.describe "JSON:API media type negotiation", type: :request do
  let(:probe_path) { "/api/__task_five__/negotiation" }

  before do
    stub_const("TaskFiveNegotiationProbeController", Class.new(ApiController) do
      def probe
        head :no_content
      end
    end)

    Rails.application.routes.draw do
      match "/api/__task_five__/negotiation", to: "task_five_negotiation_probe#probe", via: :all
    end
  end

  after do
    Rails.application.reload_routes!
  end

  def expect_error(status:, code:, parameter: nil)
    error = parsed_body.fetch("errors").first

    expect(response).to have_http_status(status)
    expect(response.headers.fetch("Content-Type")).to eq(JsonapiRequestHelper::JSONAPI_MEDIA_TYPE)
    expect(error).to include("status" => status.to_s, "code" => code)
    expect(error.fetch("source")).to eq("parameter" => parameter) if parameter
  end

  it "accepts compatible ranges and valid quoted profile URI lists" do
    compatible_accepts = [
      "application/vnd.api+json",
      " Application/Vnd.Api+Json ",
      'application/vnd.api+json;profile="https://example.com/resource-timestamps"',
      'application/vnd.api+json;profile="https://example.com/one urn:example:two"',
      "text/plain;q=0.1, application/vnd.api+json;q=0.8",
      'application/json;note="comma,inside", application/vnd.api+json;q=0.7',
      "application/*",
      "*/*"
    ]

    compatible_accepts.each do |accept|
      get probe_path, headers: { "ACCEPT" => accept }

      expect(response).to have_http_status(:no_content), "expected #{accept.inspect} to be compatible"
    end
  end

  it "rejects unsupported, malformed, or unquoted JSON:API Accept parameters" do
    incompatible_accepts = [
      "application/json",
      "application/vnd.api+json;charset=utf-8",
      'application/vnd.api+json;ext="https://jsonapi.org/ext/version"',
      'application/vnd.api+json;ext="https://jsonapi.org/ext/version", */*;q=1',
      "application/vnd.api+json;profile=example",
      'application/vnd.api+json;profile=""',
      'application/vnd.api+json;profile="/relative"',
      'application/vnd.api+json;profile="not-a-uri"',
      "application/vnd.api+json;q=0",
      "application/vnd.api+json;q=invalid",
      'application/vnd.api+json;q="0.7"',
      "application/vnd.api+json;q = 0.7",
      "application/vnd.api+json;q=0.1234",
      "application/vnd.api+json;q=0.5;q=0.8"
    ]

    incompatible_accepts.each do |accept|
      get probe_path, headers: { "ACCEPT" => accept }

      expect_error(status: 406, code: "NOT_ACCEPTABLE", parameter: "Accept")
    end
  end

  it "uses another valid JSON:API candidate when one candidate is unsupported" do
    get probe_path,
        headers: {
          "ACCEPT" => [
            'application/vnd.api+json;ext="https://jsonapi.org/ext/version"',
            'application/vnd.api+json;profile="https://example.com/profile"'
          ].join(", ")
        }

    expect(response).to have_http_status(:no_content)
  end

  it "requires Content-Type only for write requests with at least one raw body byte" do
    %i[post put patch delete].each do |method|
      public_send(method, probe_path, headers: { "ACCEPT" => JsonapiRequestHelper::JSONAPI_MEDIA_TYPE })

      expect(response).to have_http_status(:no_content)
    end

    post probe_path,
         params: " \t",
         headers: {
           "ACCEPT" => JsonapiRequestHelper::JSONAPI_MEDIA_TYPE,
           "CONTENT_TYPE" => "application/json"
         }

    expect_error(status: 415, code: "UNSUPPORTED_MEDIA_TYPE", parameter: "Content-Type")
  end

  it "accepts exact JSON:API Content-Type and valid quoted profiles" do
    compatible_content_types = [
      "application/vnd.api+json",
      'application/vnd.api+json;profile="https://example.com/profile"',
      ' Application/Vnd.Api+Json ; profile="https://example.com/one urn:example:two" '
    ]

    compatible_content_types.each do |content_type|
      post probe_path,
           params: { data: {} }.to_json,
           headers: {
             "ACCEPT" => JsonapiRequestHelper::JSONAPI_MEDIA_TYPE,
             "CONTENT_TYPE" => content_type
           }

      expect(response).to have_http_status(:no_content), "expected #{content_type.inspect} to be compatible"
    end
  end

  it "rejects unsupported ext and malformed or unquoted Content-Type parameters" do
    incompatible_content_types = [
      "application/json",
      "application/vnd.api+json;charset=utf-8",
      'application/vnd.api+json;ext="https://jsonapi.org/ext/version"',
      "application/vnd.api+json;profile=example",
      'application/vnd.api+json;profile=""',
      'application/vnd.api+json;profile="/relative"',
      'application/vnd.api+json;profile="not-a-uri"'
    ]

    incompatible_content_types.each do |content_type|
      post probe_path,
           params: { data: {} }.to_json,
           headers: {
             "ACCEPT" => JsonapiRequestHelper::JSONAPI_MEDIA_TYPE,
             "CONTENT_TYPE" => content_type
           }

      expect_error(status: 415, code: "UNSUPPORTED_MEDIA_TYPE", parameter: "Content-Type")
    end
  end

  it "maps a whitespace JSON:API body to INVALID_JSONAPI_DOCUMENT" do
    post probe_path,
         params: " \t",
         headers: jsonapi_headers

    expect_error(status: 400, code: "INVALID_JSONAPI_DOCUMENT")
  end

  it "maps malformed JSON to INVALID_JSONAPI_DOCUMENT" do
    post probe_path,
         params: '{"data":',
         headers: jsonapi_headers

    expect_error(status: 400, code: "INVALID_JSONAPI_DOCUMENT")
  end

  it "rejects a JSON:API request document without data" do
    post probe_path,
         params: { meta: { requestId: "safe" } }.to_json,
         headers: jsonapi_headers

    expect_error(status: 400, code: "INVALID_JSONAPI_DOCUMENT")
    expect(parsed_body.dig("errors", 0, "source")).to eq("pointer" => "/data")
  end
end
