# frozen_string_literal: true

class AuthServiceClient
  class AuthenticationError < StandardError; end
  class ServiceUnavailableError < StandardError; end
  class CircuitOpenError < ServiceUnavailableError; end

  # Circuit Breaker configuration
  FAILURE_THRESHOLD = 5
  RESET_TIMEOUT = 30 # seconds

  # NOTE: Circuit state는 프로세스 메모리에 저장됩니다.
  # Puma multi-worker 환경에서는 각 worker가 독립적인 circuit state를 가집니다.
  # 정확한 circuit breaking이 필요하면 Redis 기반 구현을 고려하세요.
  class << self
    def circuit_state
      @circuit_state ||= { state: :closed, failure_count: 0, last_failure_at: nil }
    end

    def circuit_mutex
      @circuit_mutex ||= Mutex.new
    end

    def record_success
      circuit_mutex.synchronize do
        circuit_state[:state] = :closed
        circuit_state[:failure_count] = 0
        circuit_state[:last_failure_at] = nil
      end
    end

    def record_failure
      circuit_mutex.synchronize do
        circuit_state[:failure_count] += 1
        circuit_state[:last_failure_at] = Time.current
        if circuit_state[:failure_count] >= FAILURE_THRESHOLD
          circuit_state[:state] = :open
        end
      end
    end

    def circuit_open?
      circuit_mutex.synchronize do
        return false if circuit_state[:state] == :closed

        if circuit_state[:state] == :open
          if circuit_state[:last_failure_at] && Time.current - circuit_state[:last_failure_at] >= RESET_TIMEOUT
            circuit_state[:state] = :half_open
            return false
          end
          return true
        end

        false # half_open allows requests through
      end
    end

    def reset_circuit!
      circuit_mutex.synchronize do
        @circuit_state = { state: :closed, failure_count: 0, last_failure_at: nil }
      end
    end
  end

  def verify_session(bearer_token)
    if self.class.circuit_open?
      raise CircuitOpenError, "인증 서비스가 일시적으로 이용 불가합니다. 잠시 후 다시 시도해주세요."
    end

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
    when 200
      self.class.record_success
      parse_user_response(response.body)
    when 401
      # 401 is a valid auth rejection, not a service failure
      raise AuthenticationError, "인증에 실패했습니다."
    else
      self.class.record_failure
      raise ServiceUnavailableError, "인증 서비스에 연결할 수 없습니다."
    end
  rescue Faraday::TimeoutError, Faraday::ConnectionFailed
    self.class.record_failure
    raise ServiceUnavailableError, "인증 서비스에 연결할 수 없습니다."
  end

  def connection
    @connection ||= Faraday.new(url: config.url) do |conn|
      conn.request :json
      conn.response :json
      conn.request :retry, max: 2, interval: 0.1, retry_statuses: [ 502, 503, 504 ]
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
