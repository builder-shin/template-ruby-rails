# frozen_string_literal: true

require "rails_helper"

RSpec.describe "GET /api/v1/users/me", type: :request do
  let(:path) { "/api/v1/users/me" }

  def expect_auth_error(status, code, source: nil)
    expect(response).to have_http_status(status)
    expect(response.headers.fetch("Content-Type")).to eq(JsonapiRequestHelper::JSONAPI_MEDIA_TYPE)
    error = parsed_body.fetch("errors").first
    expect(error).to include("status" => Rack::Utils.status_code(status).to_s, "code" => code)
    expect(error["source"]).to eq(source) if source
  end

  it "returns the authenticated user's own profile" do
    user = mock_bearer_user(email: "profile@example.com")

    get path, headers: jsonapi_headers.merge(auth_bearer_headers)

    expect(response).to have_http_status(:ok)
    document = parsed_body
    resource = document.fetch("data")
    attributes = resource.fetch("attributes")
    expect(resource.fetch("type")).to eq("users")
    expect(resource.fetch("id")).to eq(user.id)
    expect(attributes.fetch("email")).to eq("profile@example.com")
    expect(attributes.fetch("isActive")).to be(true)
    expect(Time.iso8601(attributes.fetch("createdAt"))).to be_within(1.second).of(user.created_at)
    expect(Time.iso8601(attributes.fetch("updatedAt"))).to be_within(1.second).of(user.updated_at)
    # self 링크는 항상 /api/v1/users/me다 — user.id로 조립한 /api/v1/users/{id}가
    # 아니다. 그런 라우트는 존재하지 않는다(config/routes.rb에 없다).
    expect(resource.dig("links", "self")).to eq("/api/v1/users/me")
    expect(document).not_to have_key("meta")
  end

  # 정본에서 확인한 사실이자 이 엔드포인트가 있는 이유: /users/me는
  # get_current_user를 쓰지 get_current_active_user를 쓰지 않는다 — 비활성
  # 사용자도 "내 계정이 비활성 상태다"라는 사실 자체는 볼 수 있어야 누구에게
  # 문의해야 할지 안다. ExamplesController(authenticate_active_user!)와 결정적으로
  # 갈리는 자리라 이 테스트가 가장 중요하다.
  it "returns 200 for an inactive user instead of 403" do
    mock_inactive_bearer_user

    get path, headers: jsonapi_headers.merge(auth_bearer_headers)

    expect(response).to have_http_status(:ok)
    expect(parsed_body.dig("data", "attributes", "isActive")).to be(false)
  end

  it "returns 401 AUTHENTICATION_REQUIRED without an Authorization header" do
    get path, headers: jsonapi_headers

    expect_auth_error(:unauthorized, "AUTHENTICATION_REQUIRED", source: { "header" => "Authorization" })
  end

  it "returns 401 INVALID_TOKEN for a non-Bearer Authorization header" do
    get path, headers: jsonapi_headers.merge("Authorization" => "Token abc123")

    expect_auth_error(:unauthorized, "INVALID_TOKEN", source: { "header" => "Authorization" })
  end

  it "returns 401 TOKEN_EXPIRED for an expired access token" do
    user = create(:user)
    token = Auth::Tokens.create(user.id, type: "access", now: 1.hour.ago)

    get path, headers: jsonapi_headers.merge(auth_bearer_headers(token))

    expect_auth_error(:unauthorized, "TOKEN_EXPIRED", source: { "header" => "Authorization" })
  end

  it "returns 401 INVALID_TOKEN when a refresh token is presented as an access token" do
    user = create(:user)
    refresh_token = Auth::Tokens.create(user.id, type: "refresh")

    get path, headers: jsonapi_headers.merge(auth_bearer_headers(refresh_token))

    expect_auth_error(:unauthorized, "INVALID_TOKEN", source: { "header" => "Authorization" })
  end

  it "returns 401 INVALID_TOKEN when the token's subject has no matching user" do
    token = Auth::Tokens.create(SecureRandom.uuid, type: "access")

    get path, headers: jsonapi_headers.merge(auth_bearer_headers(token))

    expect_auth_error(:unauthorized, "INVALID_TOKEN", source: { "header" => "Authorization" })
  end

  it "does not authenticate via the legacy session_web cookie" do
    get path, headers: jsonapi_headers.merge(auth_cookie_headers("looks-legit"))

    expect_auth_error(:unauthorized, "AUTHENTICATION_REQUIRED", source: { "header" => "Authorization" })
  end
end
