# frozen_string_literal: true

class RefreshSession < ApplicationRecord
  belongs_to :user
  belongs_to :replaced_by, class_name: "RefreshSession", optional: true

  # `uniqueness: true`를 두지 않는다 — Task 5가 `User#email`에 세운 원칙과 같은
  # 자리다(`app/models/user.rb` 참고): 유니크는 오직 DB 유니크 인덱스
  # (`index_refresh_sessions_on_token_hash`)로만 강제한다. 정본도 같다 —
  # `app/models/refresh_session.py:32`의 `unique=True`가 전부이고 애플리케이션
  # 레벨 사전 조회는 없다.
  #
  # **다만 `User#email`과 영향의 크기가 다르다는 것을 분명히 해 둔다.** 저쪽은
  # 사전 조회가 흔한 경우(중복 가입)의 관측 가능한 결과를 바꿨다 — DB 인덱스보다
  # 검증기가 먼저 걸려 409 EMAIL_ALREADY_REGISTERED여야 할 것이 422로 나갔다.
  # 여기서 검증기가 걸리려면 SHA-256 충돌이 필요하므로 오늘 관측 가능한 동작
  # 차이는 없다. 그럼에도 지우는 이유는 둘이다:
  #
  #   1. 비용. 이 검증기는 **로그인마다·회전마다** `SELECT 1 AS one FROM
  #      refresh_sessions WHERE token_hash = $1 LIMIT $2` 왕복을 하나 더 낸다
  #      (실측: 로그인 5문장 중 1개, 회전 7문장 중 1개). 도달 불가능한 경우를
  #      막으려고 인증 핫패스에 매번 왕복을 더한다.
  #   2. 만에 하나 걸렸을 때의 모양. 검증기가 있으면 `RecordInvalid` →
  #      422 VALIDATION_ERROR + `pointer: "/data/attributes/tokenHash"`가 된다 —
  #      요청 문서의 type은 `authCredentials`/`refreshTokens`이고 `tokenHash`라는
  #      멤버는 애초에 없으므로, 내부 컬럼 이름을 공개 오류에 흘리면서 가리키는
  #      곳도 없는 pointer다. 검증기가 없으면 같은 사건이 `RecordNotUnique` →
  #      409 RESOURCE_CONFLICT로 나간다(JsonapiErrors의 rescue_from).
  validates :token_hash, presence: true
  validates :expires_at, presence: true
end
