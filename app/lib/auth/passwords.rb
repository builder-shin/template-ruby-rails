# frozen_string_literal: true

require "argon2"
require "securerandom"

module Auth
  # argon2 비밀번호 해시와 검증.
  #
  # bcrypt를 쓰지 않는 이유는 72바이트에서 잘라내기 때문이다. 계약상 비밀번호가
  # 12~128자이므로 bcrypt를 쓰면 73바이트부터 다른 두 비밀번호가 모두 로그인에
  # 성공하는 상태가 조용히 생긴다.
  module Passwords
    module_function

    def hash_password(raw)
      Argon2::Password.create(raw)
    end

    # 컨테이너에서 실측: 틀린 비밀번호(형식이 맞는 해시 앞)는 예외 없이 false를
    # 반환한다. 반면 저장된 해시 자체가 argon2 형식이 아니면(빈 문자열, 자리표시자
    # 문자열, 손상된 데이터 등) Argon2::ArgonHashFail이 올라온다. 이 메서드는 그
    # 예외를 잡지 않는다 — 정본(FastAPI PASSWORD_HASH.verify, NestJS
    # verifyPassword)도 잡지 않는다. NestJS의 verifyPassword 주석이 이유를 명시한다:
    # "해시 문자열 자체가 깨졌으면 예외가 그대로 올라간다 — 그것은 사용자 입력이
    # 아니라 저장된 데이터의 손상이고, '비밀번호가 틀렸다'로 위장되면 원인을 찾을
    # 길이 없어진다." 여기서 손상된 해시가 나올 수 있는 유일한 경로(팩토리의
    # 자리표시자 문자열)는 이 태스크가 실제 해시 호출로 바꾸면서 이미 없앴다.
    def verify_password(raw, stored_hash)
      Argon2::Password.verify_password(raw, stored_hash)
    end

    # 이메일이 없을 때도 검증을 한 번 돌리기 위한 더미 해시다 — 스펙 6.5.
    # 즉시 반환하면 응답 시간이 "그 계정은 없다"를 알려 준다. 최초 호출 시점에
    # 만들어 프로세스 동안 캐시한다(정본은 모듈 로드 시점에 만들지만, Ruby에서는
    # 이 initializer가 아직 없는 rake task·마이그레이션 실행 등에서도 매번 이
    # 파일이 로드되므로 첫 실제 사용 시점까지 해시 비용을 미루는 쪽을 택했다).
    def dummy_hash
      @dummy_hash ||= hash_password(SecureRandom.hex(32))
    end
  end
end
