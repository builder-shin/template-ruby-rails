# frozen_string_literal: true

require "rails_helper"

RSpec.describe "Example authentication boundary", type: :request do
  let(:collection_path) { "/api/v1/examples" }

  before do
    AuthServiceClient.reset_circuit!
    Rails.cache.clear
  end

  def resource_path(example_or_id)
    "#{collection_path}/#{example_or_id.respond_to?(:id) ? example_or_id.id : example_or_id}"
  end

  def relationship_path(example, name)
    "#{resource_path(example)}/relationships/#{name}"
  end

  def example_document(id: nil, title: "Authenticated write")
    data = {
      type: "examples",
      attributes: { title: title, status: "draft", score: 0 }
    }
    data[:id] = id if id
    { data: data }
  end

  def relationship_document(data)
    { data: data }
  end

  def perform_jsonapi(method, path, body: nil, headers: jsonapi_headers)
    public_send(method, path, params: body&.to_json, headers: headers)
  end

  def expect_auth_error(status, code, leaked_detail: nil)
    expect(response).to have_http_status(status)
    expect(response.headers.fetch("Content-Type")).to eq(JsonapiRequestHelper::JSONAPI_MEDIA_TYPE)
    expect(parsed_body.fetch("errors").first).to include(
      "status" => Rack::Utils.status_code(status).to_s,
      "code" => code
    )
    expect(response.body).not_to include(leaked_detail) if leaked_detail
  end

  def auth_user_response(member_status: "active")
    {
      success: true,
      data: {
        id: SecureRandom.uuid,
        email: "auth@example.com",
        name: "Auth User",
        workspace_id: SecureRandom.uuid,
        workspace_kind: "personal",
        workspace_role: "owner",
        member_status: member_status
      }
    }
  end

  def stub_auth_request(token, response)
    stub_request(:get, "#{Rails.application.config.x.auth_service.url}/api/auth/me")
      .with(headers: { "Cookie" => "session_web=#{token}" })
      .to_return(response)
  end

  it "쿠키와 외부 인증 호출 없이 모든 읽기 엔드포인트를 공개한다" do
    category = create(:example_category)
    tag = create(:example_tag)
    example = create(:example, category: category)
    create(:example_tagging, example: example, example_tag: tag)
    expect_any_instance_of(AuthServiceClient).not_to receive(:verify_session)

    [
      [ collection_path, :ok ],
      [ resource_path(example), :ok ],
      [ relationship_path(example, "category"), :ok ],
      [ "#{resource_path(example)}/category", :ok ],
      [ relationship_path(example, "tags"), :ok ],
      [ "#{resource_path(example)}/tags", :ok ]
    ].each do |path, status|
      get path, headers: jsonapi_headers

      expect(response).to have_http_status(status)
    end
  end

  it "stale cookie가 있어도 6개 공개 읽기에서 Auth 조회를 생략한다" do
    category = create(:example_category)
    tag = create(:example_tag)
    example = create(:example, category: category)
    create(:example_tagging, example: example, example_tag: tag)
    auth_client = instance_double(AuthServiceClient)
    allow(AuthServiceClient).to receive(:new).and_return(auth_client)
    allow(auth_client).to receive(:verify_session).and_return(nil)
    paths = [
      collection_path,
      resource_path(example),
      relationship_path(example, "category"),
      "#{resource_path(example)}/category",
      relationship_path(example, "tags"),
      "#{resource_path(example)}/tags"
    ]

    paths.each do |path|
      get path, headers: jsonapi_headers.merge(auth_cookie_headers("stale-session"))

      expect(response).to have_http_status(:ok)
    end
    expect(auth_client).not_to have_received(:verify_session)
  end

  it "Auth 장애를 6개 공개 읽기와 분리하되 쓰기 503 경계는 유지한다" do
    category = create(:example_category)
    tag = create(:example_tag)
    example = create(:example, category: category)
    create(:example_tagging, example: example, example_tag: tag)
    auth_client = instance_double(AuthServiceClient)
    allow(AuthServiceClient).to receive(:new).and_return(auth_client)
    allow(auth_client).to receive(:verify_session)
      .and_raise(AuthServiceClient::ServiceUnavailableError, "outage secret")
    headers = jsonapi_headers.merge(auth_cookie_headers("outage-session"))
    paths = [
      collection_path,
      resource_path(example),
      relationship_path(example, "category"),
      "#{resource_path(example)}/category",
      relationship_path(example, "tags"),
      "#{resource_path(example)}/tags"
    ]

    paths.each do |path|
      get path, headers: headers

      expect(response).to have_http_status(:ok)
    end
    expect(auth_client).not_to have_received(:verify_session)

    perform_jsonapi(:post, collection_path, body: example_document, headers: headers)

    expect_auth_error(:service_unavailable, "AUTH_SERVICE_UNAVAILABLE", leaked_detail: "outage secret")
    expect(auth_client).to have_received(:verify_session).once
  end

  it "쿠키가 없으면 정확히 8개 쓰기 액션을 401로 거부한다" do
    example = create(:example)
    category = create(:example_category)
    tag = create(:example_tag)
    update_document = example_document(id: example.id)
    tag_linkage = relationship_document([ { type: "exampleTags", id: tag.id } ])
    writes = [
      [ :post, collection_path, example_document ],
      [ :patch, resource_path(example), update_document ],
      [ :put, resource_path(example), update_document ],
      [ :delete, resource_path(example), nil ],
      [ :patch, relationship_path(example, "category"),
       relationship_document({ type: "exampleCategories", id: category.id }) ],
      [ :post, relationship_path(example, "tags"), tag_linkage ],
      [ :patch, relationship_path(example, "tags"), tag_linkage ],
      [ :delete, relationship_path(example, "tags"), tag_linkage ]
    ]
    expect_any_instance_of(AuthServiceClient).not_to receive(:verify_session)

    writes.each do |method, path, body|
      perform_jsonapi(method, path, body: body)

      expect_auth_error(:unauthorized, "AUTHENTICATION_REQUIRED")
    end
  end

  it "익명 쓰기에서 media negotiation을 인증보다 먼저 적용한다" do
    example = create(:example)
    category = create(:example_category)
    tag = create(:example_tag)
    update_document = example_document(id: example.id)
    tag_linkage = relationship_document([ { type: "exampleTags", id: tag.id } ])
    writes = [
      [ :post, collection_path, example_document ],
      [ :patch, resource_path(example), update_document ],
      [ :put, resource_path(example), update_document ],
      [ :delete, resource_path(example), nil ],
      [
        :patch,
        relationship_path(example, "category"),
        relationship_document({ type: "exampleCategories", id: category.id })
      ],
      [ :post, relationship_path(example, "tags"), tag_linkage ],
      [ :patch, relationship_path(example, "tags"), tag_linkage ],
      [ :delete, relationship_path(example, "tags"), tag_linkage ]
    ]
    expect_any_instance_of(AuthServiceClient).not_to receive(:verify_session)

    writes.each do |method, path, body|
      aggregate_failures("#{method} #{path} Accept") do
        perform_jsonapi(
          method,
          path,
          body: body,
          headers: jsonapi_headers.merge("ACCEPT" => "application/json")
        )

        expect_auth_error(:not_acceptable, "NOT_ACCEPTABLE")
        expect(parsed_body.dig("errors", 0, "source")).to eq("parameter" => "Accept")
      end
    end

    writes.reject { |method, path, body| method == :delete && path == resource_path(example) && body.nil? }
      .each do |method, path, body|
        aggregate_failures("#{method} #{path} Content-Type") do
          perform_jsonapi(
            method,
            path,
            body: body,
            headers: jsonapi_headers.merge("CONTENT_TYPE" => "application/json")
          )

          expect_auth_error(:unsupported_media_type, "UNSUPPORTED_MEDIA_TYPE")
          expect(parsed_body.dig("errors", 0, "source")).to eq("parameter" => "Content-Type")
        end
      end
  end

  it "정상 media의 unsupported query를 인증보다 먼저 거부한다" do
    expect_any_instance_of(AuthServiceClient).not_to receive(:verify_session)

    perform_jsonapi(
      :post,
      "#{collection_path}?fields[examples]=title",
      body: example_document
    )

    expect_auth_error(:bad_request, "INVALID_QUERY_PARAMETER")
    expect(parsed_body.dig("errors", 0, "source")).to eq("parameter" => "fields[examples]")
  end

  it "anonymous DELETE는 존재하지 않는 UUID도 조회 전에 401로 거부한다" do
    expect_any_instance_of(AuthServiceClient).not_to receive(:verify_session)

    perform_jsonapi(:delete, resource_path(SecureRandom.uuid))

    expect_auth_error(:unauthorized, "AUTHENTICATION_REQUIRED")
  end

  it "active cookie DELETE는 인증을 한 번만 확인한 뒤 존재하지 않는 UUID를 404로 반환한다" do
    token = "missing-resource-session"
    auth_url = "#{Rails.application.config.x.auth_service.url}/api/auth/me"
    stub_auth_request(
      token,
      status: 200,
      body: auth_user_response.to_json,
      headers: { "Content-Type" => "application/json" }
    )

    perform_jsonapi(
      :delete,
      resource_path(SecureRandom.uuid),
      headers: jsonapi_headers.merge(auth_cookie_headers(token))
    )

    expect_auth_error(:not_found, "RESOURCE_NOT_FOUND")
    expect(WebMock).to have_requested(:get, auth_url)
      .with(headers: { "Cookie" => "session_web=#{token}" }).once
  end

  it "Authorization header만으로는 인증하지 않는다" do
    expect_any_instance_of(AuthServiceClient).not_to receive(:verify_session)

    perform_jsonapi(
      :post,
      collection_path,
      body: example_document,
      headers: jsonapi_headers.merge("Authorization" => "Bearer ignored-token")
    )

    expect_auth_error(:unauthorized, "AUTHENTICATION_REQUIRED")
  end

  it "유효한 session_web 쿠키로 쓰기를 허용한다" do
    token = "valid-session"
    stub_auth_request(
      token,
      status: 200,
      body: auth_user_response.to_json,
      headers: { "Content-Type" => "application/json" }
    )

    perform_jsonapi(
      :post,
      collection_path,
      body: example_document,
      headers: jsonapi_headers.merge(auth_cookie_headers(token))
    )

    expect(response).to have_http_status(:created)
    expect(Example.find(parsed_body.dig("data", "id"))).to have_attributes(title: "Authenticated write")
  end

  it "외부 인증의 401을 anonymous로 취급해 보호 액션에서 안전한 401을 반환한다" do
    token = "rejected-session"
    stub_auth_request(token, status: 401, body: { error: "upstream secret" }.to_json)

    perform_jsonapi(
      :post,
      collection_path,
      body: example_document,
      headers: jsonapi_headers.merge(auth_cookie_headers(token))
    )

    expect_auth_error(:unauthorized, "AUTHENTICATION_REQUIRED", leaked_detail: "upstream secret")
  end

  it "malformed JSON 외부 401도 status를 우선해 안전한 401로 변환한다" do
    token = "malformed-401-session"
    leaked_body = "upstream-401-secret:{"
    stub_auth_request(
      token,
      status: 401,
      body: leaked_body,
      headers: { "Content-Type" => "application/json" }
    )

    perform_jsonapi(
      :post,
      collection_path,
      body: example_document,
      headers: jsonapi_headers.merge(auth_cookie_headers(token))
    )

    expect_auth_error(:unauthorized, "AUTHENTICATION_REQUIRED", leaked_detail: leaked_body)
  end

  it "외부 인증 timeout을 안전한 503으로 변환한다" do
    token = "timeout-session"
    stub_request(:get, "#{Rails.application.config.x.auth_service.url}/api/auth/me").to_timeout

    perform_jsonapi(
      :post,
      collection_path,
      body: example_document,
      headers: jsonapi_headers.merge(auth_cookie_headers(token))
    )

    expect_auth_error(:service_unavailable, "AUTH_SERVICE_UNAVAILABLE")
  end

  it "외부 인증 connection failure를 안전한 503으로 변환한다" do
    token = "connection-session"
    stub_request(:get, "#{Rails.application.config.x.auth_service.url}/api/auth/me")
      .to_raise(Faraday::ConnectionFailed.new("connection secret"))

    perform_jsonapi(
      :post,
      collection_path,
      body: example_document,
      headers: jsonapi_headers.merge(auth_cookie_headers(token))
    )

    expect_auth_error(:service_unavailable, "AUTH_SERVICE_UNAVAILABLE", leaked_detail: "connection secret")
  end

  it "외부 인증 5xx를 안전한 503으로 변환한다" do
    token = "server-error-session"
    stub_auth_request(token, status: 500, body: { error: "upstream secret" }.to_json)

    perform_jsonapi(
      :post,
      collection_path,
      body: example_document,
      headers: jsonapi_headers.merge(auth_cookie_headers(token))
    )

    expect_auth_error(:service_unavailable, "AUTH_SERVICE_UNAVAILABLE", leaked_detail: "upstream secret")
  end

  it "malformed JSON 외부 5xx도 status를 우선해 안전한 503으로 변환한다" do
    token = "malformed-500-session"
    leaked_body = "upstream-500-secret:{"
    stub_auth_request(
      token,
      status: 500,
      body: leaked_body,
      headers: { "Content-Type" => "application/json" }
    )

    perform_jsonapi(
      :post,
      collection_path,
      body: example_document,
      headers: jsonapi_headers.merge(auth_cookie_headers(token))
    )

    expect_auth_error(:service_unavailable, "AUTH_SERVICE_UNAVAILABLE", leaked_detail: leaked_body)
  end

  it "malformed JSON 외부 200을 안전한 503으로 변환하고 실패로 기록한다" do
    token = "malformed-200-session"
    leaked_body = "upstream-200-secret:{"
    stub_auth_request(
      token,
      status: 200,
      body: leaked_body,
      headers: { "Content-Type" => "application/json" }
    )

    perform_jsonapi(
      :post,
      collection_path,
      body: example_document,
      headers: jsonapi_headers.merge(auth_cookie_headers(token))
    )

    expect_auth_error(:service_unavailable, "AUTH_SERVICE_UNAVAILABLE", leaked_detail: leaked_body)
    expect(AuthServiceClient.circuit_state.fetch(:failure_count)).to eq(1)
  end

  it "열린 circuit을 안전한 503으로 변환하고 외부 호출을 생략한다" do
    AuthServiceClient::FAILURE_THRESHOLD.times { AuthServiceClient.record_failure }
    expect(AuthServiceClient.circuit_open?).to be(true)
    expect(WebMock).not_to have_requested(:get, /api\/auth\/me/)

    perform_jsonapi(
      :post,
      collection_path,
      body: example_document,
      headers: jsonapi_headers.merge(auth_cookie_headers("circuit-open-session"))
    )

    expect_auth_error(:service_unavailable, "AUTH_SERVICE_UNAVAILABLE")
    expect(WebMock).not_to have_requested(:get, /api\/auth\/me/)
  end

  it "비활성 사용자의 쓰기를 403으로 거부한다" do
    token = "inactive-session"
    stub_auth_request(
      token,
      status: 200,
      body: auth_user_response(member_status: "inactive").to_json,
      headers: { "Content-Type" => "application/json" }
    )

    perform_jsonapi(
      :post,
      collection_path,
      body: example_document,
      headers: jsonapi_headers.merge(auth_cookie_headers(token))
    )

    expect_auth_error(:forbidden, "FORBIDDEN")
    expect(Example.count).to eq(0)
  end
end
