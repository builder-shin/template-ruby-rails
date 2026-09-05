# frozen_string_literal: true

FactoryBot.define do
  factory :user do
    sequence(:email) { |number| "user#{number}@example.com" }

    # TODO(Task 2): argon2가 아직 이 저장소에 없다. 이 고정 문자열은 자리표시자일
    # 뿐이며 argon2 해시 형식이 아니라서 검증에 쓰면 항상 실패한다. Task 2가
    # Auth::Passwords를 추가하면 `Auth::Passwords.hash_password("password")`
    # 호출로 바꿔야 한다 — 바꾸지 않으면 Task 5의 로그인 테스트가 저장된 해시가
    # argon2 형식이 아니어서 검증이 항상 false가 되는, 원인을 알기 어려운 방식으로
    # 실패한다.
    password_hash { "placeholder-hash-not-argon2" }
    is_active { true }
  end

  factory :refresh_session do
    association :user
    token_hash { SecureRandom.hex(32) }
    expires_at { 30.days.from_now }
    revoked_at { nil }
    replaced_by { nil }
  end
end
