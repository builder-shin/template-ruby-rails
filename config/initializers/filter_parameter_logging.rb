# Be sure to restart your server when you modify this file.

# Configure parameters to be partially matched (e.g. passw matches password) and filtered from the log file.
# Use this to limit dissemination of sensitive information.
# See the ActiveSupport::ParameterFilter documentation for supported notations and behaviors.

if Rails.env.production?
  Rails.application.config.filter_parameters += [ :passw, :email, :phone, :secret, :token, :_key, :crypt, :salt, :certificate, :otp, :ssn ]
end

if Rails.env.development?
  # 개발 환경에서는 디버깅을 위해 파라미터 필터링을 비활성화합니다.
  # 주의: 개발 로그에 민감 정보가 평문으로 기록될 수 있습니다.
  Rails.application.config.filter_parameters = []
end
