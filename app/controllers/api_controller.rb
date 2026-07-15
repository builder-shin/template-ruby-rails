# frozen_string_literal: true

class ApiController < ApplicationController
  include CrudActions

  before_action :set_current_user

  def user_info
    Current.user
  end

  def require_authenticated_user!
    raise ::JsonApiError.new(status: 401, code: "AUTHENTICATION_REQUIRED") if user_info.nil?
  end

  def require_active_user!
    require_authenticated_user!
    raise ::JsonApiError.new(status: 403, code: "FORBIDDEN") unless user_info.active?
  end

  def user_check!
    require_authenticated_user!
  end

  def enterprise_check!
    user_check!
    raise ::JsonApiError.new(status: 403, code: "FORBIDDEN") unless user_info.enterprise?
  end

  def personal_check!
    user_check!
    raise ::JsonApiError.new(status: 403, code: "FORBIDDEN") unless user_info.personal?
  end

  private

  def set_current_user
    token = extract_session_token
    return unless token

    Current.user = auth_service.verify_session(token)
  rescue AuthServiceClient::AuthenticationError
    nil
  rescue AuthServiceClient::ServiceUnavailableError
    raise ::JsonApiError.new(status: 503, code: "AUTH_SERVICE_UNAVAILABLE")
  end

  def extract_session_token
    request.cookies["session_web"]
  end

  def auth_service
    @auth_service ||= AuthServiceClient.new
  end
end
