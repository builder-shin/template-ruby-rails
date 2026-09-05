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

  def expect_auth_error(status, code, source: nil, leaked_detail: nil)
    expect(response).to have_http_status(status)
    expect(response.headers.fetch("Content-Type")).to eq(JsonapiRequestHelper::JSONAPI_MEDIA_TYPE)
    error = parsed_body.fetch("errors").first
    expect(error).to include(
      "status" => Rack::Utils.status_code(status).to_s,
      "code" => code
    )
    expect(error["source"]).to eq(source) if source
    expect(response.body).not_to include(leaked_detail) if leaked_detail
  end

  it "인증 정보 없이 모든 읽기 엔드포인트를 공개한다" do
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

  it "무효한 인증 정보가 있어도 6개 공개 읽기에서 인증 조회를 생략한다" do
    # 낡은 session_web 쿠키와 엉터리 Bearer 토큰을 함께 실어 본다 — 읽기는 둘 중
    # 어느 메커니즘도 거치지 않는다는 것을 증명한다(ExamplesController가 모든
    # 액션에서 skip_before_action :set_current_user이고, authenticate_active_user!는
    # PROTECTED_WRITE_ACTIONS에만 붙는다).
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
    headers = jsonapi_headers.merge(auth_cookie_headers("stale-session")).merge("Authorization" => "Bearer garbage-token")

    paths.each do |path|
      get path, headers: headers

      expect(response).to have_http_status(:ok)
    end
    expect(auth_client).not_to have_received(:verify_session)
  end

  it "Authorization 헤더가 없으면 정확히 8개 쓰기 액션을 401 AUTHENTICATION_REQUIRED로 거부한다" do
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

      expect_auth_error(:unauthorized, "AUTHENTICATION_REQUIRED", source: { "header" => "Authorization" })
    end
  end

  it "세션 쿠키만으로는 더 이상 쓰기를 인증하지 않는다" do
    # 계약이 뒤집힌 자리: 예전에는 session_web 쿠키만이 쓰기를 인증했고
    # Authorization 헤더는 무시됐다. 이제는 반대다 — 이 테스트가 옛 메커니즘이
    # 조용히 되살아나지 않는다는 것을 고정한다.
    perform_jsonapi(
      :post,
      collection_path,
      body: example_document,
      headers: jsonapi_headers.merge(auth_cookie_headers("looks-legit"))
    )

    expect_auth_error(:unauthorized, "AUTHENTICATION_REQUIRED", source: { "header" => "Authorization" })
    expect(Example.count).to eq(0)
  end

  it "Bearer 스킴이 아니거나 형식이 깨진 Authorization 헤더는 401 INVALID_TOKEN을 반환한다" do
    # 마지막 값이 핵심이다(뮤테이션 테스트로 찾음): 스킴 검사를 통째로 지워도
    # "Basic dGVzdDp0ZXN0"·"Bearer"·"sometoken"은 credential 부분 자체가
    # 서명된 JWT가 아니라서 decode가 어차피 실패해 같은 INVALID_TOKEN이 나온다 —
    # 그 셋만으로는 스킴 검사가 실제로 도는지 전혀 구분하지 못했다. 스킴만 틀리고
    # credential은 진짜 유효한 access token인 경우라야 스킴 검사가 없으면 통과해
    # 버린다는 게 드러난다.
    user = create(:user)
    valid_token = Auth::Tokens.create(user.id, type: "access")

    [ "Basic dGVzdDp0ZXN0", "Bearer", "sometoken", "Basic #{valid_token}" ].each do |header_value|
      aggregate_failures(header_value) do
        perform_jsonapi(
          :post,
          collection_path,
          body: example_document,
          headers: jsonapi_headers.merge("Authorization" => header_value)
        )

        expect_auth_error(:unauthorized, "INVALID_TOKEN", source: { "header" => "Authorization" })
      end
    end
    expect(Example.count).to eq(0)
  end

  it "만료된 access 토큰은 401 TOKEN_EXPIRED를 반환한다" do
    user = create(:user)
    token = Auth::Tokens.create(user.id, type: "access", now: 1.hour.ago)

    perform_jsonapi(
      :post,
      collection_path,
      body: example_document,
      headers: jsonapi_headers.merge(auth_bearer_headers(token))
    )

    expect_auth_error(:unauthorized, "TOKEN_EXPIRED", source: { "header" => "Authorization" })
    expect(Example.count).to eq(0)
  end

  it "서명이 깨진 토큰은 내부 정보를 노출하지 않고 401 INVALID_TOKEN을 반환한다" do
    user = create(:user)
    token = Auth::Tokens.create(user.id, type: "access")
    header, payload, signature = token.split(".")
    tampered_first_char = signature[0] == "A" ? "B" : "A"
    tampered_token = [ header, payload, tampered_first_char + signature[1..] ].join(".")

    perform_jsonapi(
      :post,
      collection_path,
      body: example_document,
      headers: jsonapi_headers.merge(auth_bearer_headers(tampered_token))
    )

    expect_auth_error(:unauthorized, "INVALID_TOKEN", source: { "header" => "Authorization" }, leaked_detail: user.email)
    expect(Example.count).to eq(0)
  end

  it "refresh 토큰을 access 자리에 제시하면 401 INVALID_TOKEN을 반환한다" do
    user = create(:user)
    refresh_token = Auth::Tokens.create(user.id, type: "refresh")

    perform_jsonapi(
      :post,
      collection_path,
      body: example_document,
      headers: jsonapi_headers.merge(auth_bearer_headers(refresh_token))
    )

    expect_auth_error(:unauthorized, "INVALID_TOKEN", source: { "header" => "Authorization" })
    expect(Example.count).to eq(0)
  end

  it "sub가 가리키는 사용자가 없으면 401 INVALID_TOKEN을 반환한다" do
    token = Auth::Tokens.create(SecureRandom.uuid, type: "access")

    perform_jsonapi(
      :post,
      collection_path,
      body: example_document,
      headers: jsonapi_headers.merge(auth_bearer_headers(token))
    )

    expect_auth_error(:unauthorized, "INVALID_TOKEN", source: { "header" => "Authorization" })
    expect(Example.count).to eq(0)
  end

  it "비활성 사용자의 쓰기를 403 USER_INACTIVE로 거부한다" do
    mock_inactive_bearer_user

    perform_jsonapi(:post, collection_path, body: example_document, headers: jsonapi_headers.merge(auth_bearer_headers))

    expect_auth_error(:forbidden, "USER_INACTIVE")
    # 정본과 같다: USER_INACTIVE는 인증 헤더 자체의 문제가 아니라 사용자를
    # 특정한 뒤의 권한 거부라 source.header를 싣지 않는다.
    expect(parsed_body.dig("errors", 0)).not_to have_key("source")
    expect(Example.count).to eq(0)
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

  it "유효한 Bearer 토큰으로 쓰기를 허용한다" do
    mock_bearer_user

    perform_jsonapi(:post, collection_path, body: example_document, headers: jsonapi_headers.merge(auth_bearer_headers))

    expect(response).to have_http_status(:created)
    expect(Example.find(parsed_body.dig("data", "id"))).to have_attributes(title: "Authenticated write")
  end

  it "유효한 Bearer 토큰의 DELETE는 존재하지 않는 UUID를 404로 반환한다" do
    mock_bearer_user

    perform_jsonapi(:delete, resource_path(SecureRandom.uuid), headers: jsonapi_headers.merge(auth_bearer_headers))

    expect_auth_error(:not_found, "RESOURCE_NOT_FOUND")
  end
end
