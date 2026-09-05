# frozen_string_literal: true

module AuthHelper
  # --- 레거시 쿠키 흐름 -----------------------------------------------------
  # 아래 네 메서드는 ApiController#set_current_user(AuthServiceClient 기반)를
  # 직접 시험하는 자리에서만 쓴다 — jsonapi_errors_spec.rb의 "ApiController error
  # conversion"처럼 그 컨트롤러의 레거시 메서드(user_check!, enterprise_check! 등)를
  # 독립적으로 확인하는 스펙이다. ExamplesController의 쓰기 인증은 Task 4부터 이
  # 흐름을 타지 않는다 — 아래 mock_bearer_user/auth_bearer_headers를 쓴다.
  def mock_authenticated_user(attrs = {})
    user = AuthUser.new({
      id: SecureRandom.uuid,
      email: "test@example.com",
      name: "Test User",
      workspace_id: SecureRandom.uuid,
      workspace_kind: "personal",
      workspace_role: "owner",
      member_status: "active"
    }.merge(attrs))

    allow_any_instance_of(AuthServiceClient).to receive(:verify_session).and_return(user)
    user
  end

  def mock_enterprise_user(attrs = {})
    mock_authenticated_user(attrs.merge(workspace_kind: "enterprise"))
  end

  def mock_unauthenticated
    allow_any_instance_of(AuthServiceClient).to receive(:verify_session).and_return(nil)
  end

  def mock_auth_service_unavailable
    allow_any_instance_of(AuthServiceClient).to receive(:verify_session)
      .and_raise(AuthServiceClient::ServiceUnavailableError, "인증 서비스에 연결할 수 없습니다.")
  end

  def auth_cookie_headers(token = "valid_token")
    { "COOKIE" => "session_web=#{token}" }
  end

  # --- Bearer 흐름 -----------------------------------------------------------
  # JsonapiAuthentication이 실제로 검증할 수 있는 진짜 User와 access token을
  # 만든다. 레거시 메서드들과 달리 AuthServiceClient를 스텁하지 않는다 — 가짜
  # 토큰이 아니라 실제로 서명된 JWT라서 컨트롤러의 가드가 그대로 통과시킨다.
  #
  # 발급한 token은 auth_bearer_headers가 인자 없이도 쓸 수 있게 저장해 둔다.
  # 두 메서드를 짝지어 쓰는 게 전제다: `before { mock_bearer_user }` 뒤에
  # `jsonapi_headers.merge(auth_bearer_headers)`처럼 쓴다.
  def mock_bearer_user(attrs = {})
    user = create(:user, **attrs)
    @__bearer_token = Auth::Tokens.create(user.id, type: "access")
    user
  end

  def mock_inactive_bearer_user(attrs = {})
    mock_bearer_user(attrs.merge(is_active: false))
  end

  # token을 생략하면 가장 최근 mock_bearer_user(또는 mock_inactive_bearer_user)가
  # 발급한 token을 쓴다. 아직 아무도 부르지 않았다면 명시적으로 실패한다 — 조용히
  # 빈 문자열로 "Bearer "를 보내면 401 INVALID_TOKEN이 나서 "인증이 아예 안 됐다"와
  # "의도적으로 잘못된 토큰을 보냈다"를 구분하지 못하는 테스트가 생긴다.
  def auth_bearer_headers(token = nil)
    token ||= @__bearer_token || (raise "mock_bearer_user를 먼저 불러야 auth_bearer_headers를 쓸 수 있다")
    { "Authorization" => "Bearer #{token}" }
  end
end

RSpec.configure do |config|
  config.include AuthHelper, type: :request
  config.include AuthHelper, type: :controller
end
