# frozen_string_literal: true

require "jwt"
require "digest"
require "active_support/security_utils"

module Auth
  # HS256 JWT 발급·해석과 refresh token 해시 원시 함수.
  #
  # access와 refresh 토큰은 같은 7개 클레임 모양이다 — sub·jti·type·iat·exp·iss·aud.
  # type만 다르다. refresh 토큰의 jti는 refresh_sessions.id와 같은 값이 되어(Task 3+)
  # 토큰과 세션 행을 연결한다.
  module Tokens
    # 서명·클레임 검증에 실패했을 때. 원인(서명 위조, iss/aud 불일치, 필수 클레임
    # 누락, 타입 불일치 등)을 구분하지 않는다 — 호출자 입장에서는 전부 "이 토큰을
    # 신뢰할 수 없다"는 같은 결론이다.
    class InvalidToken < StandardError; end

    # 그 외에는 유효했지만 만료된 토큰. InvalidToken과 구분하는 이유는 refresh
    # 회전 로직이 "다시 로그인해야 한다"와 "이 refresh token으로 갱신하면 된다"를
    # 구분해야 하기 때문이다.
    class TokenExpired < StandardError; end

    Claims = Struct.new(:sub, :jti, :type, :iat, :exp, :iss, :aud, keyword_init: true)

    ALGORITHM = "HS256"
    TOKEN_TYPES = %w[access refresh].freeze
    REQUIRED_CLAIMS = %w[sub jti type iat exp iss aud].freeze
    # SecureRandom.uuid가 만드는 표준 8-4-4-4-12 하이픈 형식. 우리가 발급하는
    # jti는 전부 이 형식이므로, decode 쪽도 이 형식만 "UUID로 파싱된다"로 받아들인다.
    JTI_PATTERN = /\A[0-9a-fA-F]{8}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{12}\z/

    # Ruby의 Time.at은 임의의 bignum이나 ±Infinity/NaN까지 받아들이려 든다(±Infinity·
    # NaN은 FloatDomainError로 죽지만, 10**30처럼 터무니없이 큰 유한수는 예외 없이
    # "서기 3경 년" 같은 Time을 그냥 만들어 버린다 — 절대 만료되지 않는 토큰이 조용히
    # 생긴다). 정본은 datetime.fromtimestamp가 알아서 이 범위를 막아 주지만
    # (datetime.min/max 밖이면 raise) Ruby에는 그런 안전장치가 없어 직접 막는다. 경계는
    # 정본의 datetime.min/datetime.max와 맞췄다 — datetime(1,1,1)과
    # datetime(9999,12,31,23,59,59)의 UTC epoch초.
    MIN_TIMESTAMP = -62_135_596_800
    MAX_TIMESTAMP = 253_402_300_799

    module_function

    def create(subject, type:, jti: nil, now: nil)
      raise ArgumentError, "type must be one of #{TOKEN_TYPES}" unless TOKEN_TYPES.include?(type)

      issued_at = (now || Time.now).to_i
      lifetime = type == "access" ? config.access_expires_seconds : config.refresh_expires_seconds
      payload = {
        sub: subject.to_s,
        jti: (jti || SecureRandom.uuid).to_s,
        type: type,
        iat: issued_at,
        exp: issued_at + lifetime,
        iss: config.issuer,
        aud: config.audience
      }
      JWT.encode(payload, config.secret_key, ALGORITHM)
    end

    def decode(token, expected_type:)
      typed_claims(decode_payload(token, verify_expiration: true), expected_type: expected_type)
    end

    # refresh 회전 중 "만료된 refresh token"을 의도적으로 한 번 더 읽는다 — 만료만
    # 눈감아 주고 나머지(서명·iss·aud·필수 클레임 등)는 그대로 검증한다.
    # expected_type을 항상 "refresh"로 고정하는 이유는 이 메서드를 부르는 자리
    # 자체가 이미 refresh 토큰이라는 문맥이기 때문이다 — access 토큰의 만료를
    # 눈감아 줄 이유는 없다.
    def decode_expired_refresh(token)
      typed_claims(decode_payload(token, verify_expiration: false), expected_type: "refresh")
    end

    def hash_refresh_token(token)
      Digest::SHA256.hexdigest(token)
    end

    def refresh_token_matches?(token, stored_hash)
      ActiveSupport::SecurityUtils.secure_compare(hash_refresh_token(token), stored_hash)
    end

    def decode_payload(token, verify_expiration:)
      # ruby-jwt 3.2.0을 컨테이너에서 실측: token이 String이 아니면(Integer/Float/
      # Array/Hash/true/Symbol 등) `JWT::EncodedToken#initialize`가
      # `ArgumentError, "Provided JWT must be a String"`를 던진다 — 아래 rescue
      # 목록(JWT::DecodeError/NoMethodError/TypeError/RangeError) 어디에도 안 걸려
      # 그대로 새어나간다. 여기서 rescue에 ArgumentError를 추가하는 대신 미리
      # 걸러내는 이유: ArgumentError는 Ruby 어디서나 나는 흔한 예외라 rescue 목록에
      # 더하면 이 메서드 안에서 일어나는(예: 설정값이 잘못돼 JWT.decode 내부가
      # 다른 이유로 ArgumentError를 내는) 진짜 프로그래밍 오류까지 "이 토큰을
      # 신뢰할 수 없다"로 뭉개 버릴 수 있다. 또한 이 가드는 ruby-jwt가 앞으로
      # 어떤 예외 타입으로 바뀌든 영향받지 않는다 — "String이 아니면 유효한
      # 토큰이 아니다"라고 여기서 직접 말하는 쪽이 서드파티 gem의 오늘 시점
      # 예외 타입에 기대는 것보다 정확하다.
      raise InvalidToken, "token must be a string" unless token.is_a?(String)

      JWT.decode(token, config.secret_key, true, {
        algorithm: ALGORITHM,
        iss: config.issuer, verify_iss: true,
        aud: config.audience, verify_aud: true,
        required_claims: REQUIRED_CLAIMS,
        verify_expiration: verify_expiration,
        leeway: config.leeway_seconds
      }).first
    rescue JWT::ExpiredSignature
      raise TokenExpired
    rescue JWT::DecodeError, NoMethodError, TypeError, RangeError
      # ruby-jwt 3.2.0을 컨테이너에서 실측: exp가 boolean이면 내장
      # Claims::Expiration이 `payload['exp'].to_i`를 그대로 호출해 NoMethodError로
      # 죽는다(JWT::DecodeError 계열이 아니다). payload가 JSON 객체가 아니라
      # 배열이면 다른 내장 검증기가 `payload['aud']`류 호출에서 TypeError를 낸다.
      # exp가 1e400처럼 JSON에서 Infinity로 파싱되는 값이면 같은 `.to_i` 호출이
      # FloatDomainError(RangeError의 서브클래스)로 죽는다. 셋 다 서명 위조·필수
      # 클레임 누락과 본질이 같은 "이 토큰을 신뢰할 수 없다"이므로 InvalidToken으로
      # 옮긴다. JWT::ExpiredSignature가 JWT::DecodeError의 서브클래스라 위 rescue보다
      # 먼저 와야 한다 — 순서를 바꾸면 만료가 InvalidToken으로 뭉개져 회전 로직이
      # 재로그인과 갱신 가능을 구분하지 못한다.
      raise InvalidToken
    end

    def typed_claims(payload, expected_type:)
      # JWT.decode(위 decode_payload)가 이미 검증한 것: HS256 서명, REQUIRED_CLAIMS
      # 전부의 존재, iss 일치(단일 문자열 대 단일 문자열 비교라 ruby-jwt에서도
      # 정확히 동등 비교다 — jwt/claims/issuer.rb 확인), aud "포함"(정확 일치 아님
      # — 아래에서 보정), exp 만료 여부.
      #
      # 이 메서드가 그 위에 더하는 것(정본 tokens.py의 _typed_claims 주석과 같은
      # 목록): 비어 있지 않은 sub, UUID로 파싱되는 jti, expected_type과 정확히
      # 같은 type, bool·문자열이 섞이지 않은 진짜 숫자 iat/exp, aud의 "포함"이
      # 아니라 "정확히 일치".
      sub = payload["sub"]
      raw_jti = payload["jti"]
      raw_type = payload["type"]
      raw_iat = payload["iat"]
      raw_exp = payload["exp"]
      aud = payload["aud"]

      raise InvalidToken, "sub must be a non-empty string" unless sub.is_a?(String) && !sub.empty?
      raise InvalidToken, "jti must be a UUID" unless raw_jti.is_a?(String) && JTI_PATTERN.match?(raw_jti)
      raise InvalidToken, "unexpected token type" unless raw_type == expected_type
      # Ruby는 true/false가 Numeric의 인스턴스가 아니어서 is_a?(Numeric) 하나로
      # bool까지 함께 걸러진다. PyJWT는 bool이 int의 서브클래스라 정본이
      # _is_numeric_date에서 bool을 별도로 걷어내야 했지만, 여기서는 그 보정이
      # 필요 없다 — 컨테이너 실측으로도 exp/iat가 문자열이거나 bool이면 이 조건에서
      # 걸리는 것을 확인했다(문자열 "1788..."은 ruby-jwt의 내장 만료 검사를
      # `.to_i`로 조용히 통과하지만, 여기서는 Numeric이 아니라서 잡힌다).
      raise InvalidToken, "iat must be numeric" unless raw_iat.is_a?(Numeric)
      raise InvalidToken, "exp must be numeric" unless raw_exp.is_a?(Numeric)
      # exp가 1e400(JSON에서 Infinity로 파싱된다)이면 decode_payload의 내장
      # 만료 검사가 먼저 크래시해 여기까지 안 온다(위 rescue가 잡는다). 하지만
      # iat는 ruby-jwt가 아예 손대지 않고(verify_iat를 안 켰다), verify_expiration을
      # 끄는 decode_expired_refresh 경로에서는 exp도 이 메서드까지 그대로 넘어온다
      # — 그래서 Infinity/NaN, 그리고 10**30처럼 유한하지만 터무니없이 큰 값(Ruby의
      # Time.at은 예외 없이 받아 준다 — "서기 3경 년" Time이 조용히 생겨 절대
      # 만료되지 않는 토큰이 된다)을 여기서 직접 막는다. finite?가 먼저 와야 한다
      # — Float::NAN.between?(a, b)는 false가 아니라 ArgumentError를 낸다.
      raise InvalidToken, "iat out of range" unless raw_iat.finite? && raw_iat.between?(MIN_TIMESTAMP, MAX_TIMESTAMP)
      raise InvalidToken, "exp out of range" unless raw_exp.finite? && raw_exp.between?(MIN_TIMESTAMP, MAX_TIMESTAMP)
      # ruby-jwt의 Claims::Audience#verify!는 `([*aud] & [*expected]).empty?`로
      # 판단한다(jwt/claims/audience.rb) — token의 aud가 배열이고 그중 하나만
      # 우리 audience와 같아도 통과시키는 "포함" 검사다. 컨테이너에서 직접 확인:
      # aud가 ["template-ruby-rails", "someone-else"]인 토큰도 decode를
      # 통과했다. 정본 주석이 PyJWT에 대해 경고하는 것과 같은 종류의 구멍이라
      # 여기서도 똑같이 보정한다 — token의 aud가 설정된 audience와 정확히 같은
      # 문자열인지 다시 본다.
      raise InvalidToken, "aud must match exactly" unless aud == config.audience

      Claims.new(
        sub: sub,
        # 정본은 UUID(raw_jti)로 파싱해 반환하고, 그 UUID를 문자열화하면 항상
        # 소문자다 — 대소문자 무관이 타입에서 공짜로 따라온다. Ruby에는 그런 타입이
        # 없고 raw_jti는 그냥 String이라, 여기서 downcase하지 않으면
        # create(jti: "5614FBF9-...")가 대문자를 그대로 왕복시킨다. Postgres uuid
        # 컬럼은 16바이트로 저장돼 DB 조회는 대소문자와 무관하지만, claims.jti를
        # Ruby String으로 직접 비교하는 자리(세션 id 대조, 로그 상관관계)는 그렇지
        # 않다 — 여기서 한 번 정규화해 두면 그 이후의 모든 소비자가 매번 기억하지
        # 않아도 정본과 같은 보장을 받는다.
        jti: raw_jti.downcase,
        type: raw_type,
        iat: Time.at(raw_iat).utc,
        exp: Time.at(raw_exp).utc,
        iss: payload["iss"],
        aud: aud
      ).freeze
    end

    def config
      Rails.application.config.x.auth
    end

    # decode_payload/typed_claims는 서명 검증 이전 단계를 손으로 조립할 수 있게
    # 노출되면 안 된다 — module_function은 그 뒤에 정의되는 메서드를 전부 public
    # 모듈 함수로도 만들어서, 여기서 private_class_method로 다시 감추지 않으면
    # `Auth::Tokens.typed_claims({"sub" => "victim", ...}, expected_type: "access")`
    # 처럼 서명 없이 Claims를 조작해 만들 수 있었다(정본이 _typed_claims로 언더스코어
    # 접두해 막는 것과 같은 이유). config는 스펙이 실제 설정 값을 읽으려고 직접
    # 부르므로 public으로 남긴다.
    private_class_method :decode_payload, :typed_claims
  end
end
