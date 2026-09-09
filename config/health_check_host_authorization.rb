# frozen_string_literal: true

# 컨테이너 헬스체크를 Host 헤더 검사(DNS rebinding 보호)에서 제외하는 술어.
#
# 두 환경(development·production)이 **같은 술어를 참조**한다. 각 환경 파일에 람다를
# 따로 적으면 한쪽만 고쳐지는 드리프트가 생기고, 실제로 그렇게 갈려 있었다 —
# production 에는 있고 development 에는 없어서 development 스테이지 컨테이너의
# 헬스체크가 `Blocked hosts: localhost:4000` 으로 항상 막혔다.
#
# `config/environments/*.rb` 는 오토로딩이 준비되기 전에 읽히므로 이 파일은
# `require_relative` 로 명시적으로 불러야 한다.
module HealthCheckHostAuthorization
  # HealthController 가 노출하는 경로들의 공통 접두사(/health/live·/health/ready).
  PATH_PREFIX = "/health"

  # config.host_authorization 의 :exclude 에 그대로 넣는다.
  EXCLUDE = ->(request) { request.path.start_with?(PATH_PREFIX) }
end
