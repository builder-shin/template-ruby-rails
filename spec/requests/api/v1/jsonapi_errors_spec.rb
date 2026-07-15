# frozen_string_literal: true

require "rails_helper"
require "yaml"

RSpec.describe "JSON:API errors", type: :request do
  EXPECTED_ERROR_CODES = %w[
    NOT_ACCEPTABLE
    UNSUPPORTED_MEDIA_TYPE
    INVALID_JSONAPI_DOCUMENT
    INVALID_QUERY_PARAMETER
    INVALID_FILTER
    INVALID_SORT
    INVALID_INCLUDE
    INVALID_PAGE
    RESOURCE_NOT_FOUND
    RELATIONSHIP_RESOURCE_NOT_FOUND
    TYPE_MISMATCH
    ID_MISMATCH
    CLIENT_GENERATED_ID_UNSUPPORTED
    RESOURCE_CONFLICT
    VALIDATION_ERROR
    INTERNAL_SERVER_ERROR
    HTTP_ERROR
    AUTHENTICATION_REQUIRED
    FORBIDDEN
    AUTH_SERVICE_UNAVAILABLE
  ].freeze

  before do
    stub_const("TaskFiveProbeController", Class.new(ApplicationController) do
      def validation_failure
        Example.new.validate!
      end

      def unexpected_failure
        raise StandardError, "PG::UndefinedTable SELECT * FROM secret_table at app/private.rb:42"
      end
    end)

    Rails.application.routes.draw do
      get "/__task_five__/validation", to: "task_five_probe#validation_failure"
      get "/__task_five__/unexpected", to: "task_five_probe#unexpected_failure"
      match "*unmatched", to: "application#route_not_found", via: :all
    end
  end

  after do
    Rails.application.reload_routes!
  end

  it "returns a localized RESOURCE_NOT_FOUND document for an unknown route" do
    get "/__task_five__/not-found", headers: { "ACCEPT" => JsonapiRequestHelper::JSONAPI_MEDIA_TYPE }

    expect(response).to have_http_status(:not_found)
    expect(response.media_type).to eq(JsonapiRequestHelper::JSONAPI_MEDIA_TYPE)
    expect(parsed_body.fetch("errors").first).to eq(
      "status" => "404",
      "code" => "RESOURCE_NOT_FOUND",
      "title" => "리소스를 찾을 수 없음",
      "detail" => "요청한 리소스를 찾을 수 없습니다."
    )
  end

  it "uses English when Accept-Language prefers English" do
    get "/__task_five__/not-found",
        headers: {
          "ACCEPT" => JsonapiRequestHelper::JSONAPI_MEDIA_TYPE,
          "ACCEPT_LANGUAGE" => "en-US, ko;q=0.5"
        }

    expect(response).to have_http_status(:not_found)
    expect(parsed_body.fetch("errors").first).to eq(
      "status" => "404",
      "code" => "RESOURCE_NOT_FOUND",
      "title" => "Resource not found",
      "detail" => "The requested resource could not be found."
    )
  end

  it "maps record validation errors to a stable attribute pointer" do
    get "/__task_five__/validation", headers: { "ACCEPT" => JsonapiRequestHelper::JSONAPI_MEDIA_TYPE }

    expect(response).to have_http_status(:unprocessable_entity)
    expect(response.media_type).to eq(JsonapiRequestHelper::JSONAPI_MEDIA_TYPE)
    expect(parsed_body.fetch("errors").first).to include(
      "status" => "422",
      "code" => "VALIDATION_ERROR",
      "source" => { "pointer" => "/data/attributes/title" }
    )
  end

  it "returns a safe localized 500 without exception internals" do
    get "/__task_five__/unexpected",
        headers: {
          "ACCEPT" => JsonapiRequestHelper::JSONAPI_MEDIA_TYPE,
          "ACCEPT_LANGUAGE" => "en"
        }

    expect(response).to have_http_status(:internal_server_error)
    expect(response.media_type).to eq(JsonapiRequestHelper::JSONAPI_MEDIA_TYPE)
    expect(parsed_body.fetch("errors").first).to eq(
      "status" => "500",
      "code" => "INTERNAL_SERVER_ERROR",
      "title" => "Internal server error",
      "detail" => "The server encountered an error while processing the request."
    )
    expect(response.body).not_to include("PG::UndefinedTable", "SELECT", "secret_table", "private.rb")
  end

  it "defines exactly the approved error codes in both locale catalogs" do
    catalogs = {
      "ko" => Rails.root.join("config/locales/jsonapi.ko.yml"),
      "en" => Rails.root.join("config/locales/jsonapi.en.yml")
    }

    catalogs.each do |locale, path|
      errors = YAML.safe_load_file(path).fetch(locale).fetch("jsonapi").fetch("errors")

      expect(errors.keys).to contain_exactly(*EXPECTED_ERROR_CODES)
      expect(errors.values).to all(include("title", "detail"))
      expect(errors.values.flat_map(&:values)).to all(be_present)
    end
  end
end
