# frozen_string_literal: true

# JWT_SECRET_KEY는 애플리케이션 코드 어디에도 기본값을 두지 않는다. AUTH_SERVICE_URL과
# 달리 development/test용 fallback도 없다 — fallback을 두면 그 문자열이 사실상 소스에
# 박힌 서명 키가 되어, 그 값으로 서명된 토큰을 누구나 위조할 수 있게 된다. 없으면
# 모든 환경에서 그대로 부팅에 실패해야 한다.
jwt_secret_key = ENV["JWT_SECRET_KEY"].presence
raise "JWT_SECRET_KEY must be set" if jwt_secret_key.nil?
raise "JWT_SECRET_KEY must be at least 32 bytes (UTF-8)" if jwt_secret_key.bytesize < 32

# ENV.fetch(name, default).to_i는 "JWT_ACCESS_EXPIRES_SECONDS=abc" 같은 오타를 조용히
# 0으로 바꿔버린다 — access token이 발급 즉시 만료되는 사고가 이름 없는 오류도 없이
# 일어난다. Integer()로 엄격하게 파싱해 변수 이름을 담은 오류로 부팅을 멈춘다.
read_int = lambda do |name, default|
  Integer(ENV.fetch(name, default))
rescue ArgumentError, TypeError
  raise "#{name} must be a valid integer"
end

# issuer/audience는 완전히 없으면 기본값을 쓰지만, 값이 있는데 빈 문자열/공백이면
# 그대로 통과시키지 않는다 — aud/iss는 이 태스크가 엄격 일치로 비교하는 클레임이라,
# 조용히 기본값으로 바뀌면 운영자가 설정했다고 믿는 값과 실제 검증에 쓰이는 값이
# 갈리는 채로 시스템이 계속 뜬다.
issuer = ENV.key?("JWT_ISSUER") ? ENV["JWT_ISSUER"] : "template-ruby-rails"
raise "JWT_ISSUER must not be blank" if issuer.strip.empty?

audience = ENV.key?("JWT_AUDIENCE") ? ENV["JWT_AUDIENCE"] : "template-ruby-rails"
raise "JWT_AUDIENCE must not be blank" if audience.strip.empty?

access_expires_seconds = read_int.call("JWT_ACCESS_EXPIRES_SECONDS", 900)
refresh_expires_seconds = read_int.call("JWT_REFRESH_EXPIRES_SECONDS", 2_592_000)
leeway_seconds = read_int.call("JWT_LEEWAY_SECONDS", 0)
refresh_session_retention_seconds = read_int.call("REFRESH_SESSION_RETENTION_SECONDS", 604_800)

raise "JWT_ACCESS_EXPIRES_SECONDS must be greater than zero" if access_expires_seconds <= 0
raise "JWT_REFRESH_EXPIRES_SECONDS must be greater than zero" if refresh_expires_seconds <= 0
raise "JWT_LEEWAY_SECONDS must not be negative" if leeway_seconds.negative?
raise "REFRESH_SESSION_RETENTION_SECONDS must not be negative" if refresh_session_retention_seconds.negative?

Rails.application.config.x.auth = ActiveSupport::OrderedOptions.new
Rails.application.config.x.auth.secret_key = jwt_secret_key
Rails.application.config.x.auth.issuer = issuer
Rails.application.config.x.auth.audience = audience
Rails.application.config.x.auth.access_expires_seconds = access_expires_seconds
Rails.application.config.x.auth.refresh_expires_seconds = refresh_expires_seconds
Rails.application.config.x.auth.leeway_seconds = leeway_seconds
# refresh_sessions 정리 job(Task 7)의 보존 기간이다. JWT 서명과 무관한 값이지만,
# 이 저장소의 Rails 초기화는 프로세스별(web/worker)로 다른 config를 조립할 수 없어
# 정본(FastAPI)처럼 별도 설정 클래스로 분리해도 "JWT_SECRET_KEY 없는 worker" 문제를
# 피하지 못한다 — 모든 initializer가 매 프로세스 부팅마다 함께 실행된다. 그래서
# 같은 네임스페이스에 둔다.
Rails.application.config.x.auth.refresh_session_retention_seconds = refresh_session_retention_seconds
