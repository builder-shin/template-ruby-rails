<!-- Parent: ../AGENTS.md -->
<!-- Generated: 2026-02-06 -->

# Services (app/services/)

## Purpose
서비스 객체 디렉토리. 복잡한 비즈니스 로직, 외부 API 연동, 트랜잭션 처리 등을 담당합니다. 현재는 외부 인증 서비스 클라이언트만 포함되어 있습니다.

## Key Files
| File | Description |
|------|-------------|
| `auth_service_client.rb` | 외부 인증 서비스 HTTP 클라이언트 (세션 토큰 검증, 사용자 정보 조회) |

## Subdirectories
| Directory | Purpose |
|-----------|---------|
| (없음) | 모든 서비스가 flat 구조로 배치됨 |

## For AI Agents

### Working In This Directory
서비스 객체 작업 시:

1. **단일 책임 원칙**: 하나의 서비스는 하나의 책임만
2. **외부 API 연동**: Faraday gem 사용, 재시도 및 타임아웃 설정
3. **캐싱**: Rails.cache로 API 응답 캐싱 (성능 최적화)
4. **에러 핸들링**: 커스텀 에러 클래스 정의 및 처리
5. **테스트 가능**: 의존성 주입 또는 모킹 가능한 구조

### Common Patterns

#### AuthServiceClient (외부 인증 서비스)
```ruby
class AuthServiceClient
  class AuthenticationError < StandardError; end
  class ServiceUnavailableError < StandardError; end

  # 세션 토큰 검증 및 사용자 정보 조회
  def verify_session(bearer_token)
    cache_key = "auth:session:#{Digest::SHA256.hexdigest(bearer_token)}"

    Rails.cache.fetch(cache_key, expires_in: config.cache_ttl.seconds) do
      fetch_user_from_auth_service(bearer_token)
    end
  end

  private

  def fetch_user_from_auth_service(bearer_token)
    response = connection.get("/api/auth/me") do |req|
      req.headers["Cookie"] = "session_web=#{bearer_token}"
    end

    case response.status
    when 200 then parse_user_response(response.body)
    when 401 then raise AuthenticationError, "인증에 실패했습니다."
    else raise ServiceUnavailableError, "인증 서비스에 연결할 수 없습니다."
    end
  rescue Faraday::TimeoutError, Faraday::ConnectionFailed
    raise ServiceUnavailableError, "인증 서비스에 연결할 수 없습니다."
  end

  def connection
    @connection ||= Faraday.new(url: config.url) do |conn|
      conn.request :json
      conn.response :json
      conn.request :retry, max: 2, interval: 0.1, retry_statuses: [502, 503, 504]
      conn.options.timeout = config.timeout
    end
  end

  def parse_user_response(body)
    return nil unless body["success"] && body["data"]

    AuthUser.new(
      body["data"].slice("id", "email", "name", "workspace_id",
                         "workspace_kind", "workspace_role", "member_status")
    )
  end

  def config
    Rails.application.config.x.auth_service
  end
end
```

#### 컨트롤러에서 사용
```ruby
class ApiController < ApplicationController
  def user_info
    return @user_info if defined?(@user_info)

    session_token = cookies[:session_web]
    return nil unless session_token

    # AuthServiceClient 호출
    client = AuthServiceClient.new
    @user_info = client.verify_session(session_token)
  rescue AuthServiceClient::AuthenticationError
    nil
  rescue AuthServiceClient::ServiceUnavailableError => e
    Rails.logger.error("Auth service unavailable: #{e.message}")
    nil
  end
end
```

#### 새 서비스 객체 패턴
```ruby
# app/services/notification_service.rb
class NotificationService
  class NotificationError < StandardError; end

  def initialize(user:, event:)
    @user = user
    @event = event
  end

  def send_notification
    return false unless should_notify?

    deliver_notification
    log_notification
    true
  rescue StandardError => e
    Rails.logger.error("Notification failed: #{e.message}")
    raise NotificationError, e.message
  end

  private

  def should_notify?
    @user.notification_enabled? && @event.important?
  end

  def deliver_notification
    # 알림 발송 로직
  end

  def log_notification
    # 알림 이력 저장
  end
end

# 사용
NotificationService.new(user: user, event: event).send_notification
```

#### 외부 API 연동 패턴
```ruby
class ExternalApiClient
  BASE_URL = "https://api.example.com"

  def fetch_data(params)
    response = connection.get("/api/data", params)

    case response.status
    when 200 then JSON.parse(response.body)
    when 404 then nil
    when 429 then raise RateLimitError, "요청 한도를 초과했습니다."
    else raise ApiError, "API 호출에 실패했습니다. (#{response.status})"
    end
  rescue Faraday::Error => e
    Rails.logger.error("External API error: #{e.message}")
    raise ApiError, "네트워크 오류가 발생했습니다."
  end

  private

  def connection
    @connection ||= Faraday.new(url: BASE_URL) do |conn|
      conn.request :json
      conn.response :json
      conn.request :retry, max: 3, interval: 0.5
      conn.options.timeout = 10
      conn.headers["Authorization"] = "Bearer #{api_token}"
    end
  end

  def api_token
    ENV["EXTERNAL_API_TOKEN"]
  end
end
```

#### 트랜잭션 처리 서비스
```ruby
class ProfileCompleteService
  def initialize(profile:, user:)
    @profile = profile
    @user = user
  end

  def complete!
    ActiveRecord::Base.transaction do
      @profile.update!(status: :completed, completed_at: Time.current)
      create_notification
      send_email
    end

    true
  rescue ActiveRecord::RecordInvalid => e
    Rails.logger.error("Profile completion failed: #{e.message}")
    false
  end

  private

  def create_notification
    Notification.create!(
      user_id: @user.id,
      message: "프로필이 완성되었습니다."
    )
  end

  def send_email
    ProfileMailer.completion_email(@profile).deliver_later
  end
end
```

#### 캐싱 패턴
```ruby
class DataFetchService
  CACHE_EXPIRES_IN = 1.hour

  def fetch_cached_data(key)
    cache_key = "data:#{key}"

    Rails.cache.fetch(cache_key, expires_in: CACHE_EXPIRES_IN) do
      fetch_from_external_source(key)
    end
  end

  private

  def fetch_from_external_source(key)
    # 외부 소스에서 데이터 조회 (비용이 큰 작업)
    sleep(2)  # 예시
    { key: key, data: "expensive data" }
  end
end
```

## Dependencies

### Internal
- `app/models/` - 서비스가 조작하는 모델
- `app/mailers/` - 이메일 발송 (서비스에서 호출)
- `app/jobs/` - 백그라운드 작업 (서비스에서 enqueue)

### External
- `faraday` gem - HTTP 클라이언트
- `faraday-retry` gem - 재시도 미들웨어
- Rails.cache - 캐싱 (Redis, Memcached 등)

<!-- MANUAL: -->
