# frozen_string_literal: true

# AWS SDK 설정
if Rails.env.development?
  # 개발 환경에서 SSL CRL 검증 문제 해결
  # macOS의 Ruby OpenSSL이 인증서 CRL을 검증하지 못하는 경우가 있음
  Aws.config[:ssl_verify_peer] = false
end
