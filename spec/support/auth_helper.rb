# frozen_string_literal: true

module AuthHelper
  # JsonapiAuthentication이 실제로 검증할 수 있는 진짜 User와 access token을
  # 만든다. 인증 자체를 스텁하지 않는다 — 실제로 서명된 JWT와 DB에 실재하는
  # User라서 컨트롤러의 가드가 프로덕션과 같은 경로를 그대로 지난다.
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
