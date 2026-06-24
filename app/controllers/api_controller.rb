# frozen_string_literal: true

class ApiController < ApplicationController
  include CrudActions

  before_action :set_current_user

  def user_info
    Current.user
  end

  def user_check!
    raise JsonApiError.new("Unauthorized", "로그인 후 이용해주세요.", 401) if user_info.nil?
  end

  def enterprise_check!
    user_check!
    raise JsonApiError.new("Forbidden", "기업 회원만 이용 가능합니다.", 403) unless user_info.enterprise?
  end

  def personal_check!
    user_check!
    raise JsonApiError.new("Forbidden", "개인 회원만 이용 가능합니다.", 403) unless user_info.personal?
  end

  private

  def set_current_user
    token = extract_bearer_token
    return unless token

    Current.user = auth_service.verify_session(token)
    if defined?(Sentry) && Current.user
      Sentry.set_user(id: Current.user.id, workspace_id: Current.user.workspace_id)
    end
  rescue AuthServiceClient::AuthenticationError
    nil
  rescue AuthServiceClient::ServiceUnavailableError => e
    raise JsonApiError.new("ServiceUnavailable", e.message, 503)
  end

  def extract_bearer_token
    request.cookies["session_web"]
  end

  def auth_service
    @auth_service ||= AuthServiceClient.new
  end
end
