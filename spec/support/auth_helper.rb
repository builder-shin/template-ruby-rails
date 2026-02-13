# frozen_string_literal: true

module AuthHelper
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

  def auth_headers(token = "valid_token")
    { "Authorization" => "Bearer #{token}" }
  end
end

RSpec.configure do |config|
  config.include AuthHelper, type: :request
  config.include AuthHelper, type: :controller
end
