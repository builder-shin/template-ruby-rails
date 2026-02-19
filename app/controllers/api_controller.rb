# frozen_string_literal: true

class ApiController < ApplicationController
  include CrudActions

  before_action :set_current_user

  def user_info
    Current.user
  end

  # current_user alias (for compatibility with standard Rails patterns)
  alias_method :current_user, :user_info

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
    token = extract_session_token
    return unless token

    Current.user = auth_service.verify_session(token)
  rescue AuthServiceClient::AuthenticationError
    nil
  rescue AuthServiceClient::ServiceUnavailableError => e
    raise JsonApiError.new("ServiceUnavailable", e.message, 503)
  end

  def extract_session_token
    request.cookies['session_web']
  end

  def auth_service
    @auth_service ||= AuthServiceClient.new
  end
end
