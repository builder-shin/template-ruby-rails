# frozen_string_literal: true

# 알려진 비밀번호("password")의 argon2 해시를 파일 로드 시 한 번만 계산해 재사용한다.
# argon2 해시는 1회당 약 30ms가 걸린다(Auth::Passwords 스펙에서 실측) — 매
# factory 호출마다 새로 해시하면 이 factory를 많이 쓰는 로그인·refresh 테스트에서
# 누적 비용이 쌓인다. Auth::Passwords.dummy_hash를 프로세스당 한 번만 계산해
# 재사용하는 것과 같은 이유다. 이 값으로 실제 로그인을 검증하는 테스트는 원문
# "password"를 그대로 쓰면 되고, 다른 비밀번호가 필요하면 password_hash를
# override한다.
DEFAULT_USER_PASSWORD_HASH = Auth::Passwords.hash_password("password")

FactoryBot.define do
  factory :user do
    sequence(:email) { |number| "user#{number}@example.com" }
    password_hash { DEFAULT_USER_PASSWORD_HASH }
    is_active { true }
  end

  factory :refresh_session do
    # refresh_sessions.id는 DB 기본값이 없다 — 실제 애플리케이션은 refresh JWT의
    # jti를 id로 명시해서 넣는다(Task 3+). factory도 그 계약을 그대로 흉내 내야
    # 하므로 id를 직접 채운다; 여기를 지우면 매 create(:refresh_session)이
    # NOT NULL 위반으로 실패한다.
    id { SecureRandom.uuid }
    association :user
    token_hash { SecureRandom.hex(32) }
    expires_at { 30.days.from_now }
    revoked_at { nil }
    replaced_by { nil }
  end
end
