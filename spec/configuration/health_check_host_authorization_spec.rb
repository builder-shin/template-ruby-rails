# frozen_string_literal: true

require "rails_helper"
require Rails.root.join("config/health_check_host_authorization").to_s

# 이 스펙은 술어를 **실제 미들웨어에 물려 동작으로** 잰다. 술어만 직접 호출하면
# ActionDispatch 가 그것을 어떻게 쓰는지는 재지 못한다.
#
# 허용 호스트·차단 호스트는 실전값(localhost·ALLOWED_HOSTS)과 **일부러 다른 값**을
# 쓴다. 실전값을 그대로 쓰면 "막혀야 할 세계"와 "통과해야 할 세계"가 우연히 같아져
# 가드가 속 빈 채로 초록이 된다.
RSpec.describe HealthCheckHostAuthorization do
  let(:allowed_host) { "probe-allowed.invalid" }
  let(:blocked_host) { "probe-blocked.invalid" }

  let(:inner_app) do
    ->(_env) { [ 200, { "Content-Type" => "text/plain" }, [ "reached the app" ] ] }
  end

  let(:middleware) do
    ActionDispatch::HostAuthorization.new(inner_app, [ allowed_host ], exclude: described_class::EXCLUDE)
  end

  # HTTP_HOST 를 명시한다. ActionDispatch 가 보는 것은 Host 헤더인데
  # Rack::MockRequest.env_for 는 SERVER_NAME 만 채우고 HTTP_HOST 는 비워 둔다 —
  # 그대로 두면 허용 호스트조차 nil 로 읽혀 모든 요청이 막힌다.
  def response_status_for(path, host:)
    env = Rack::MockRequest.env_for("http://#{host}#{path}", "HTTP_HOST" => host)
    middleware.call(env).first
  end

  # 라우터에서 실제 헬스 경로를 뽑는다. 목록을 손으로 적으면 라우트가 옮겨간 날
  # 이 스펙만 초록으로 남는다.
  def health_check_paths
    Rails.application.routes.routes
         .map { |route| route.path.spec.to_s.sub(/\(\.:format\)\z/, "") }
         .select { |path| path.start_with?(described_class::PATH_PREFIX) }
  end

  it "헬스 경로를 라우터에서 실제로 찾는다" do
    expect(health_check_paths).to contain_exactly("/health/live", "/health/ready")
  end

  it "허용 목록에 없는 Host 로 와도 헬스 경로는 앱까지 닿는다" do
    health_check_paths.each do |path|
      expect(response_status_for(path, host: blocked_host)).to eq(200), "#{path} 가 막혔다"
    end
  end

  it "헬스가 아닌 경로는 허용 목록에 없는 Host 를 그대로 막는다" do
    expect(response_status_for("/api/v1/examples", host: blocked_host)).to eq(403)
  end

  it "허용 목록에 있는 Host 는 어느 경로든 통과한다" do
    expect(response_status_for("/api/v1/examples", host: allowed_host)).to eq(200)
    expect(response_status_for("/health/ready", host: allowed_host)).to eq(200)
  end

  describe "환경 배선" do
    # 술어를 두 환경이 **같은 상수로** 참조하는지 본다. 각 환경 파일에 람다를
    # 따로 적으면 위의 동작 스펙은 그대로 초록인 채 한쪽 환경만 갈린다 —
    # 실제로 그렇게 갈려 있었다(development 에 예외가 없었다).
    %w[development production].each do |environment|
      it "#{environment}.rb 가 공유 술어를 참조한다" do
        source = Rails.root.join("config/environments/#{environment}.rb").read

        expect(source).to include('require_relative "../health_check_host_authorization"')
        expect(source).to include("config.host_authorization = { exclude: HealthCheckHostAuthorization::EXCLUDE }")
      end
    end
  end
end
