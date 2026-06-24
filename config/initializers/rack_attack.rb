# frozen_string_literal: true

class Rack::Attack
  # Throttle all requests by IP (300 requests per 5 minutes)
  throttle("req/ip", limit: 300, period: 5.minutes) do |req|
    req.ip
  end

  # Throttle POST requests to /api/v1/recruitment_requests (unauthenticated create)
  throttle("recruitment_requests/ip", limit: 5, period: 1.minute) do |req|
    req.ip if req.path.start_with?("/api/v1/recruitment_requests") && req.post?
  end

  # Throttle login attempts (auth callback)
  throttle("auth/ip", limit: 10, period: 1.minute) do |req|
    req.ip if req.path.start_with?("/auth")
  end

  # Block suspicious requests
  blocklist("block bad IPs") do |req|
    Rack::Attack::Allow2Ban.filter(req.ip, maxretry: 20, findtime: 1.minute, bantime: 1.hour) do
      req.path.include?("/etc/passwd") || req.path.include?("wp-admin")
    end
  end

  # Custom throttle response
  self.throttled_responder = lambda do |_request|
    [
      429,
      { "Content-Type" => "application/vnd.api+json" },
      [ { errors: [ { status: "429", title: "Too Many Requests", detail: "요청이 너무 많습니다. 잠시 후 다시 시도해주세요." } ] }.to_json ]
    ]
  end
end
