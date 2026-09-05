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
    INVALID_TOKEN
    TOKEN_EXPIRED
    USER_INACTIVE
    EMAIL_ALREADY_REGISTERED
    INVALID_CREDENTIALS
    TOKEN_REVOKED
  ].freeze

  def expect_error(status:, code:)
    expect(response).to have_http_status(status)
    expect(response.headers.fetch("Content-Type")).to eq(JsonapiRequestHelper::JSONAPI_MEDIA_TYPE)
    expect(parsed_body.fetch("errors").first).to include("status" => status.to_s, "code" => code)
  end

  describe "production routing" do
    it "keeps ActiveStorage direct uploads ahead of the API fallback" do
      route = Rails.application.routes.recognize_path(
        "/rails/active_storage/direct_uploads",
        method: :post
      )

      expect(route).to include(controller: "active_storage/direct_uploads", action: "create")
    end

    it "returns an exact JSON:API 404 for an unknown API route" do
      get "/api/v1/task-five-not-found", headers: { "ACCEPT" => JsonapiRequestHelper::JSONAPI_MEDIA_TYPE }

      expect_error(status: 404, code: "RESOURCE_NOT_FOUND")
      expect(parsed_body.fetch("errors").first).to eq(
        "status" => "404",
        "code" => "RESOURCE_NOT_FOUND",
        "title" => "리소스를 찾을 수 없음",
        "detail" => "요청한 리소스를 찾을 수 없습니다."
      )
    end

    it "uses English and varies the cache key by Accept-Language" do
      get "/api/v1/task-five-not-found",
          headers: {
            "ACCEPT" => JsonapiRequestHelper::JSONAPI_MEDIA_TYPE,
            "ACCEPT_LANGUAGE" => "en-US, ko;q=0.5"
          }

      expect_error(status: 404, code: "RESOURCE_NOT_FOUND")
      expect(response.headers.fetch("Vary").split(",").map(&:strip)).to include("Accept-Language")
      expect(parsed_body.fetch("errors").first).to include(
        "title" => "Resource not found",
        "detail" => "The requested resource could not be found."
      )
    end
  end

  describe "ApiController error conversion" do
    let(:base_path) { "/api/__task_five__/errors" }

    before do
      stub_const("TaskFiveApiProbeController", Class.new(ApiController) do
        def klass
          Example
        end

        def parameter_missing
          params.require(:data)
        end

        def authentication_required
          user_check!
        end

        def forbidden
          enterprise_check!
        end

        def validation_failure
          Example.new.validate!
        end

        def unexpected_failure
          response.headers["Vary"] = "Origin, Accept"
          raise StandardError, "PG::UndefinedTable SELECT * FROM secret_table at app/private.rb:42"
        end

        def typo_code
          raise ::JsonApiError.new(status: 400, code: "TYPO_CODE")
        end
      end)

      Rails.application.routes.draw do
        get "/api/__task_five__/errors/parameter_missing", to: "task_five_api_probe#parameter_missing"
        get "/api/__task_five__/errors/authentication_required", to: "task_five_api_probe#authentication_required"
        get "/api/__task_five__/errors/forbidden", to: "task_five_api_probe#forbidden"
        get "/api/__task_five__/errors/validation", to: "task_five_api_probe#validation_failure"
        get "/api/__task_five__/errors/unexpected", to: "task_five_api_probe#unexpected_failure"
        get "/api/__task_five__/errors/typo", to: "task_five_api_probe#typo_code"
        get "/api/__task_five__/errors/examples/:id", to: "task_five_api_probe#show"
      end
    end

    after do
      Rails.application.reload_routes!
    end

    it "does not retain legacy JsonApiError constants or rescue handlers" do
      expect(ApiController.const_defined?(:JsonApiError, false)).to be(false)
      expect(ApiController.const_get(:JsonApiError)).to equal(JsonApiError)
      expect(ApiController.rescue_handlers.map(&:last)).not_to include(
        :render_jsonapi_internal_server_error,
        :render_jsonapi_not_found,
        :render_jsonapi_unprocessable_entity
      )
    end

    it "maps ParameterMissing to INVALID_JSONAPI_DOCUMENT" do
      get "#{base_path}/parameter_missing", headers: jsonapi_headers

      expect_error(status: 400, code: "INVALID_JSONAPI_DOCUMENT")
    end

    it "maps the real CrudActions show lookup to a localized RESOURCE_NOT_FOUND" do
      get "#{base_path}/examples/#{SecureRandom.uuid}",
          headers: jsonapi_headers(language: "en")

      expect_error(status: 404, code: "RESOURCE_NOT_FOUND")
      expect(parsed_body.fetch("errors").first).to include("title" => "Resource not found")
    end

    it "maps missing authentication to AUTHENTICATION_REQUIRED" do
      get "#{base_path}/authentication_required", headers: jsonapi_headers

      expect_error(status: 401, code: "AUTHENTICATION_REQUIRED")
    end

    it "maps authorization failure to FORBIDDEN" do
      mock_authenticated_user

      get "#{base_path}/forbidden", headers: jsonapi_headers(cookie: "valid-session")

      expect_error(status: 403, code: "FORBIDDEN")
    end

    it "maps auth service failures to AUTH_SERVICE_UNAVAILABLE without exposing details" do
      mock_auth_service_unavailable

      get "#{base_path}/authentication_required", headers: jsonapi_headers(cookie: "valid-session")

      expect_error(status: 503, code: "AUTH_SERVICE_UNAVAILABLE")
      expect(response.body).not_to include("인증 서비스에 연결할 수 없습니다")
    end

    it "maps record validation errors to a stable attribute pointer" do
      get "#{base_path}/validation", headers: jsonapi_headers

      expect_error(status: 422, code: "VALIDATION_ERROR")
      expect(parsed_body.dig("errors", 0, "source")).to eq("pointer" => "/data/attributes/title")
    end

    it "returns a safe 500 for unknown error codes" do
      get "#{base_path}/typo", headers: jsonapi_headers(language: "en")

      expect_error(status: 500, code: "INTERNAL_SERVER_ERROR")
      expect(response.body).not_to include("TYPO_CODE", "translation missing")
    end

    it "returns a safe 500 when a registered error translation is missing" do
      allow(I18n).to receive(:t).and_wrap_original do |original, key, **options|
        next nil if key.to_s.start_with?("jsonapi.errors.RESOURCE_NOT_FOUND.")

        original.call(key, **options)
      end

      get "#{base_path}/examples/#{SecureRandom.uuid}", headers: jsonapi_headers(language: "en")

      expect_error(status: 500, code: "INTERNAL_SERVER_ERROR")
      expect(response.body).not_to include("RESOURCE_NOT_FOUND", "translation missing")
    end

    it "returns a safe 500 and preserves existing Vary tokens" do
      get "#{base_path}/unexpected", headers: jsonapi_headers(language: "en")

      expect_error(status: 500, code: "INTERNAL_SERVER_ERROR")
      expect(response.headers.fetch("Vary").split(",").map(&:strip)).to eq(
        [ "Origin", "Accept", "Accept-Language" ]
      )
      expect(response.body).not_to include("PG::UndefinedTable", "SELECT", "secret_table", "private.rb")
    end
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

    expect(JsonApiError::ERROR_CODES).to contain_exactly(*EXPECTED_ERROR_CODES)
  end
end
