# frozen_string_literal: true

# AWS SDK 설정
if Rails.env.development?
  # macOS의 Ruby OpenSSL이 인증서 CRL을 검증하지 못하는 경우 CA 번들 경로를 명시합니다.
  # ssl_verify_peer = false 는 MITM 공격에 취약하므로 사용하지 않습니다.
  # Homebrew로 설치한 CA 인증서 사용: brew install ca-certificates
  ca_path = ENV.fetch("SSL_CERT_FILE", nil)
  ca_path ||= "/etc/ssl/cert.pem" if File.exist?("/etc/ssl/cert.pem")
  Aws.config[:ssl_ca_bundle] = ca_path if ca_path
end
