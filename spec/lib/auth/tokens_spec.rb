# frozen_string_literal: true

require "rails_helper"
require "base64"
require "openssl"

RSpec.describe Auth::Tokens do
  # Auth::Tokens.create가 만드는 정상 모양의 payload에서 일부러 벗어난 토큰을
  # 만들 때 쓴다 — .create 자체는 항상 올바른 모양만 만들어서, decode 쪽의 방어
  # 코드를 시험하려면 서명은 진짜 설정 값으로 하되 payload는 직접 짜야 한다.
  def raw_token(payload, secret: described_class.config.secret_key)
    header = { "alg" => "HS256", "typ" => "JWT" }
    segments = [ header, payload ].map { |part| Base64.urlsafe_encode64(JSON.generate(part), padding: false) }
    signature = OpenSSL::HMAC.digest("SHA256", secret, segments.join("."))
    (segments + [ Base64.urlsafe_encode64(signature, padding: false) ]).join(".")
  end

  # F2 (팀장 fix round 1): exp/iat에 1e400 같은 리터럴을 넣은 토큰을 만들 때 쓴다.
  # JSON.generate(Float::INFINITY)는 JSON::GeneratorError로 거부되므로 raw_token으로는
  # 이 payload를 만들 수 없다 — payload JSON 텍스트를 직접 조립해서 field의 값
  # 부분만 파싱되지 않는 리터럴(`1e400`, `-1e400`)로 바꿔치기한다. 디코드 쪽에서
  # JSON.parse가 이 리터럴을 Float::INFINITY/-Float::INFINITY로 되살린다.
  def raw_token_with_literal_field(field, literal, overrides = {})
    payload = valid_payload(overrides)
    header = { "alg" => "HS256", "typ" => "JWT" }
    body = payload.map { |key, value| key == field ? "#{JSON.generate(key)}:#{literal}" : "#{JSON.generate(key)}:#{JSON.generate(value)}" }
    payload_json = "{#{body.join(',')}}"
    segments = [ Base64.urlsafe_encode64(JSON.generate(header), padding: false),
                 Base64.urlsafe_encode64(payload_json, padding: false) ]
    signature = OpenSSL::HMAC.digest("SHA256", described_class.config.secret_key, segments.join("."))
    (segments + [ Base64.urlsafe_encode64(signature, padding: false) ]).join(".")
  end

  def valid_payload(overrides = {})
    now = Time.now.to_i
    {
      "sub" => SecureRandom.uuid,
      "jti" => SecureRandom.uuid,
      "type" => "access",
      "iat" => now,
      "exp" => now + 900,
      "iss" => described_class.config.issuer,
      "aud" => described_class.config.audience
    }.merge(overrides)
  end

  describe ".create / .decode round trip" do
    it "decodes an access token issued by .create back to matching claims" do
      subject_id = SecureRandom.uuid
      token = described_class.create(subject_id, type: "access")

      claims = described_class.decode(token, expected_type: "access")

      aggregate_failures do
        expect(claims.sub).to eq(subject_id)
        expect(claims.type).to eq("access")
        expect(claims.jti).to match(described_class::JTI_PATTERN)
        expect(claims.iss).to eq(described_class.config.issuer)
        expect(claims.aud).to eq(described_class.config.audience)
        expect(claims.iat).to be_a(Time)
        expect(claims.exp).to be_a(Time)
      end
    end

    it "honors an explicit jti (refresh tokens must carry refresh_sessions.id)" do
      session_id = SecureRandom.uuid
      token = described_class.create(SecureRandom.uuid, type: "refresh", jti: session_id)

      claims = described_class.decode(token, expected_type: "refresh")

      expect(claims.jti).to eq(session_id)
    end

    it "normalizes an uppercase jti to lowercase (팀장 ruling: Auth::Tokens에서 정규화)" do
      # 정본은 UUID(raw_jti)로 파싱해 반환해서 대소문자가 타입에서 공짜로 사라진다.
      # Ruby의 jti는 그냥 String이라 여기서 명시적으로 낮추지 않으면 대문자로
      # create된 토큰이 대문자 그대로 왕복해서, Ruby String `==`로 claims.jti를
      # 비교하는 자리(세션 id 대조 등)가 어긋날 수 있다.
      uppercase_jti = "5614FBF9-3B37-4B5A-9C3D-2B6E4E1A7C9A"
      token = described_class.create(SecureRandom.uuid, type: "refresh", jti: uppercase_jti)

      claims = described_class.decode(token, expected_type: "refresh")

      expect(claims.jti).to eq(uppercase_jti.downcase)
    end

    it "honors an explicit now: and derives iat/exp from it using the configured lifetime" do
      # 실제 "현재"에 가깝되 정수 초로 미리 자른다 — JWT는 정수 epoch초만 담으므로
      # now:에 마이크로초가 남아 있으면 왕복 후 비교에서 어긋난다. 먼 과거로
      # 고정하면 access 수명(기본 900초)을 지나 decode 시점에 이미 만료돼 버린다.
      frozen_now = Time.at(Time.now.to_i).utc
      token = described_class.create(SecureRandom.uuid, type: "access", now: frozen_now)

      claims = described_class.decode(token, expected_type: "access")

      aggregate_failures do
        expect(claims.iat).to eq(frozen_now)
        expect(claims.exp).to eq(frozen_now + described_class.config.access_expires_seconds)
      end
    end

    it "gives access and refresh tokens the configured, distinct lifetimes" do
      now = Time.at(Time.now.to_i).utc
      access = described_class.decode(
        described_class.create(SecureRandom.uuid, type: "access", now: now), expected_type: "access"
      )
      refresh = described_class.decode(
        described_class.create(SecureRandom.uuid, type: "refresh", now: now), expected_type: "refresh"
      )

      aggregate_failures do
        expect(access.exp - access.iat).to eq(described_class.config.access_expires_seconds)
        expect(refresh.exp - refresh.iat).to eq(described_class.config.refresh_expires_seconds)
      end
    end

    it "rejects an unknown token type at creation instead of silently mis-pricing its lifetime" do
      # type == "access" ? ... : refresh_expires_seconds 삼항 연산이라, 여기서
      # 막지 않으면 오타(예: "acess")가 조용히 refresh 수명을 받는다.
      expect { described_class.create(SecureRandom.uuid, type: "bogus") }.to raise_error(ArgumentError)
    end
  end

  describe ".decode" do
    it "rejects a refresh token when an access token is expected" do
      refresh_token = described_class.create(SecureRandom.uuid, type: "refresh")

      expect { described_class.decode(refresh_token, expected_type: "access") }
        .to raise_error(Auth::Tokens::InvalidToken)
    end

    it "rejects a tampered signature" do
      token = described_class.create(SecureRandom.uuid, type: "access")
      tampered = token[0..-5] + (token[-4..] == "aaaa" ? "bbbb" : "aaaa")

      expect { described_class.decode(tampered, expected_type: "access") }
        .to raise_error(Auth::Tokens::InvalidToken)
    end

    it "rejects a token signed with a different secret" do
      token = raw_token(valid_payload, secret: "b" * 32)

      expect { described_class.decode(token, expected_type: "access") }
        .to raise_error(Auth::Tokens::InvalidToken)
    end

    it "raises TokenExpired, not InvalidToken, for an otherwise-valid expired token" do
      past = Time.now.to_i - 2_000
      token = raw_token(valid_payload("iat" => past, "exp" => past + 1))

      expect { described_class.decode(token, expected_type: "access") }
        .to raise_error(Auth::Tokens::TokenExpired)
    end

    it "rejects an issuer mismatch" do
      token = raw_token(valid_payload("iss" => "someone-else"))

      expect { described_class.decode(token, expected_type: "access") }
        .to raise_error(Auth::Tokens::InvalidToken)
    end

    it "rejects an audience mismatch" do
      token = raw_token(valid_payload("aud" => "someone-else"))

      expect { described_class.decode(token, expected_type: "access") }
        .to raise_error(Auth::Tokens::InvalidToken)
    end

    it "rejects an aud array that merely contains our audience among others" do
      # ruby-jwt의 내장 aud 검증은 포함(교집합) 검사라 이 토큰의 서명·iss·필수
      # 클레임이 전부 정상이면 gem 자체는 통과시킨다(jwt/claims/audience.rb,
      # 컨테이너에서 직접 확인). 이 테스트가 실패한다면 typed_claims의 aud 정확
      # 일치 보정이 사라졌다는 뜻이다.
      token = raw_token(valid_payload("aud" => [ described_class.config.audience, "someone-else" ]))

      expect { described_class.decode(token, expected_type: "access") }
        .to raise_error(Auth::Tokens::InvalidToken)
    end

    it "rejects a token missing a required claim" do
      payload = valid_payload
      payload.delete("jti")
      token = raw_token(payload)

      expect { described_class.decode(token, expected_type: "access") }
        .to raise_error(Auth::Tokens::InvalidToken)
    end

    it "rejects an empty sub" do
      token = raw_token(valid_payload("sub" => ""))

      expect { described_class.decode(token, expected_type: "access") }
        .to raise_error(Auth::Tokens::InvalidToken)
    end

    it "rejects a jti that does not parse as a UUID" do
      token = raw_token(valid_payload("jti" => "not-a-uuid"))

      expect { described_class.decode(token, expected_type: "access") }
        .to raise_error(Auth::Tokens::InvalidToken)
    end

    it "rejects boolean iat/exp instead of crashing" do
      # 컨테이너 실측: exp가 true/false이면 ruby-jwt의 내장 Claims::Expiration이
      # `payload['exp'].to_i`에서 NoMethodError로 죽는다 — decode_payload의
      # rescue가 이걸 InvalidToken으로 옮기지 않으면 이 테스트가 NoMethodError로
      # 실패한다(InvalidToken을 기대했는데 다른 예외가 새는 것도 실패로 잡힌다).
      aggregate_failures do
        expect { described_class.decode(raw_token(valid_payload("exp" => true)), expected_type: "access") }
          .to raise_error(Auth::Tokens::InvalidToken)
        expect { described_class.decode(raw_token(valid_payload("exp" => false)), expected_type: "access") }
          .to raise_error(Auth::Tokens::InvalidToken)
        expect { described_class.decode(raw_token(valid_payload("iat" => true)), expected_type: "access") }
          .to raise_error(Auth::Tokens::InvalidToken)
      end
    end

    it "rejects a numeric-looking string iat/exp (ruby-jwt's built-in check coerces via #to_i and would let it through)" do
      now = Time.now.to_i
      aggregate_failures do
        expect { described_class.decode(raw_token(valid_payload("exp" => (now + 900).to_s)), expected_type: "access") }
          .to raise_error(Auth::Tokens::InvalidToken)
        expect { described_class.decode(raw_token(valid_payload("iat" => now.to_s)), expected_type: "access") }
          .to raise_error(Auth::Tokens::InvalidToken)
      end
    end

    it "rejects an infinite exp instead of crashing (F2)" do
      # 1e400은 JSON에 담을 수 있는 리터럴이지만 JSON.parse가 Float::INFINITY로
      # 되살린다. exp가 Infinity면 decode_payload 내장 만료 검사(`payload['exp'].to_i`)가
      # FloatDomainError로 죽는다 — RangeError를 rescue에 추가하지 않으면 이 테스트가
      # InvalidToken이 아니라 FloatDomainError로 실패한다.
      token = raw_token_with_literal_field("exp", "1e400")

      expect { described_class.decode(token, expected_type: "access") }.to raise_error(Auth::Tokens::InvalidToken)
    end

    it "rejects an infinite iat instead of crashing (F2)" do
      # iat는 verify_iat를 안 켜서 ruby-jwt가 아예 손대지 않는다 — decode_payload는
      # 크래시 없이 통과하고, typed_claims의 Time.at(raw_iat)에서 FloatDomainError가
      # 난다. decode_payload의 rescue가 아니라 typed_claims 자체의 범위 검사가
      # 막아야 하는 경로다.
      token = raw_token_with_literal_field("iat", "1e400")

      expect { described_class.decode(token, expected_type: "access") }.to raise_error(Auth::Tokens::InvalidToken)
    end

    it "rejects an exp so large it would never expire, even though Time.at accepts it (F3)" do
      # Ruby의 Time.at(10**30)은 예외 없이 "서기 3경 년" Time을 만든다 — 이 검사가
      # 없으면 이 토큰은 조용히 decode에 성공하고 사실상 영원히 유효하다.
      token = raw_token(valid_payload("exp" => 10**30))

      expect { described_class.decode(token, expected_type: "access") }.to raise_error(Auth::Tokens::InvalidToken)
    end

    it "rejects an iat so large it is nonsensical, symmetric with exp (F3)" do
      token = raw_token(valid_payload("iat" => 10**30))

      expect { described_class.decode(token, expected_type: "access") }.to raise_error(Auth::Tokens::InvalidToken)
    end

    it "accepts exp exactly at the canonical's datetime.max boundary and rejects one second past it" do
      now = Time.now.to_i
      at_boundary = raw_token(valid_payload("iat" => now, "exp" => Auth::Tokens::MAX_TIMESTAMP))
      past_boundary = raw_token(valid_payload("iat" => now, "exp" => Auth::Tokens::MAX_TIMESTAMP + 1))

      aggregate_failures do
        expect { described_class.decode(at_boundary, expected_type: "access") }.not_to raise_error
        expect { described_class.decode(past_boundary, expected_type: "access") }
          .to raise_error(Auth::Tokens::InvalidToken)
      end
    end

    it "rejects an infinite exp on the decode_expired_refresh path too (F2, verify_expiration off skips the gem's own crash but not ours)" do
      past = Time.now.to_i - 2_000
      token = raw_token_with_literal_field("exp", "1e400", "type" => "refresh", "iat" => past)

      expect { described_class.decode_expired_refresh(token) }.to raise_error(Auth::Tokens::InvalidToken)
    end

    it "rejects a garbage token string, an empty string, and nil without crashing" do
      aggregate_failures do
        expect { described_class.decode("not-a-jwt", expected_type: "access") }.to raise_error(Auth::Tokens::InvalidToken)
        expect { described_class.decode("", expected_type: "access") }.to raise_error(Auth::Tokens::InvalidToken)
        expect { described_class.decode(nil, expected_type: "access") }.to raise_error(Auth::Tokens::InvalidToken)
      end
    end

    # F2 (팀장 fix round 1): ruby-jwt 3.2.0을 컨테이너에서 실측하면 token이 String이
    # 아닐 때 `JWT::EncodedToken#initialize`가 `ArgumentError, "Provided JWT must be
    # a String"`을 던지고, 이 gem 내부 예외는 decode_payload의 rescue 목록
    # (JWT::DecodeError/NoMethodError/TypeError/RangeError) 어디에도 안 걸린다 —
    # Auth::RefreshSessions.rotate/logout은 "토큰이 이상하면 전부 Failure 반환값"이라고
    # 말하는데, {"refresh_token": 123}처럼 JSON 정수로 온 값이 컨트롤러 파라미터에서
    # 그대로 여기까지 오면 그 계약이 깨져 401 대신 500이 났다. non-String 자체를
    # decode_payload 맨 앞에서 직접 거절해 이 gem 예외를 아예 만나지 않게 막는다.
    it "rejects non-String token types instead of leaking the gem's internal ArgumentError" do
      aggregate_failures do
        [ 123, 3.5, [], {}, true, false, :sym ].each do |non_string_token|
          expect { described_class.decode(non_string_token, expected_type: "access") }
            .to raise_error(Auth::Tokens::InvalidToken)
        end
      end
    end

    it "rejects a non-String token via decode_expired_refresh too (same decode_payload choke point)" do
      expect { described_class.decode_expired_refresh(12_345) }.to raise_error(Auth::Tokens::InvalidToken)
    end

    it "rejects the 'none' algorithm attack" do
      header = { "alg" => "none", "typ" => "JWT" }
      segments = [ header, valid_payload ].map { |part| Base64.urlsafe_encode64(JSON.generate(part), padding: false) }
      unsigned_token = segments.join(".") + "."

      expect { described_class.decode(unsigned_token, expected_type: "access") }
        .to raise_error(Auth::Tokens::InvalidToken)
    end
  end

  describe ".decode_expired_refresh" do
    it "accepts an expired refresh token that is otherwise valid" do
      past = Time.now.to_i - 2_000
      token = raw_token(valid_payload("type" => "refresh", "iat" => past, "exp" => past + 1))

      expect { described_class.decode_expired_refresh(token) }.not_to raise_error
    end

    it "still enforces every other check on an expired token (issuer mismatch here)" do
      past = Time.now.to_i - 2_000
      token = raw_token(valid_payload("type" => "refresh", "iat" => past, "exp" => past + 1, "iss" => "someone-else"))

      expect { described_class.decode_expired_refresh(token) }.to raise_error(Auth::Tokens::InvalidToken)
    end

    it "still rejects a non-expired token of the wrong type" do
      access_token = described_class.create(SecureRandom.uuid, type: "access")

      expect { described_class.decode_expired_refresh(access_token) }.to raise_error(Auth::Tokens::InvalidToken)
    end

    it "does not raise TokenExpired for a live (non-expired) refresh token" do
      refresh_token = described_class.create(SecureRandom.uuid, type: "refresh")

      expect { described_class.decode_expired_refresh(refresh_token) }.not_to raise_error
    end
  end

  # F4 (팀장 fix round 1): 이 조합을 Task 3가 그대로 의존한다 — refresh 회전은
  # decode에서 TokenExpired를 받으면 decode_expired_refresh로 다시 시도해 세션을
  # 회수한다. `exp: null`인 토큰은 ruby-jwt가 `nil.to_i == 0`으로 취급해 "무조건
  # 이미 만료됨"으로 보므로 decode는 InvalidToken이 아니라 TokenExpired를 던진다
  # (정본 PyJWT라면 InvalidToken이었을 지점이라 완전히 같은 분류는 아니다 — 팀장
  # 지시대로 이 축은 고치지 않는다). 중요한 건 그다음이다: decode_expired_refresh는
  # verify_expiration을 꺼서 이 nil을 만료 검사로는 안 보지만, typed_claims의
  # "exp must be numeric"(nil.is_a?(Numeric)은 false)이 여전히 막는다 — 그래서
  # 회전 경로 전체는 "제거하지 말고 손대지 말라"로 안전하게 수렴한다. 이 테스트가
  # 없으면 두 메서드 중 하나의 동작이 바뀌어도(예: nil을 numeric 취급하도록 고치는
  # 실수) 아무도 못 잡는다.
  describe "decode → TokenExpired → decode_expired_refresh composition (Task 3's rotation depends on this)" do
    it "decode reports TokenExpired for exp: null, and decode_expired_refresh on the same token still rejects it as InvalidToken" do
      token = raw_token(valid_payload("type" => "refresh", "exp" => nil))

      expect { described_class.decode(token, expected_type: "refresh") }.to raise_error(Auth::Tokens::TokenExpired)
      expect { described_class.decode_expired_refresh(token) }.to raise_error(Auth::Tokens::InvalidToken)
    end
  end

  describe ".hash_refresh_token / .refresh_token_matches?" do
    it "hashes with SHA-256 hex" do
      token = "some-refresh-token-value"

      expect(described_class.hash_refresh_token(token)).to eq(Digest::SHA256.hexdigest(token))
    end

    it "matches the same token and rejects a different one" do
      token = SecureRandom.hex(32)
      other = SecureRandom.hex(32)
      hash = described_class.hash_refresh_token(token)

      aggregate_failures do
        expect(described_class.refresh_token_matches?(token, hash)).to be(true)
        expect(described_class.refresh_token_matches?(other, hash)).to be(false)
      end
    end

    it "compares using a constant-time comparison, not ==" do
      # mutation 방지: 누군가 refresh_token_matches?를 `hash_refresh_token(token) ==
      # stored_hash`로 바꿔도 위의 "matches/rejects" 테스트는 여전히 통과한다 —
      # 결과값은 같기 때문이다. 이 테스트는 결과가 아니라 *어떻게* 비교했는지를
      # 확인해서 그 회귀를 잡는다.
      expect(ActiveSupport::SecurityUtils).to receive(:secure_compare).and_call_original

      described_class.refresh_token_matches?("token", described_class.hash_refresh_token("token"))
    end
  end

  # F5 (팀장 fix round 1): module_function은 뒤에 정의되는 메서드를 전부 public
  # 모듈 함수로도 만든다 — private_class_method로 다시 감추지 않으면 서명 검증을
  # 건너뛰고 `Auth::Tokens.typed_claims({"sub" => "victim", ...}, expected_type:
  # "access")`처럼 인증되지 않은 신원을 담은 Claims를 그냥 만들 수 있었다.
  describe "internal helpers are not part of the public API" do
    it "does not expose decode_payload or typed_claims outside the module" do
      aggregate_failures do
        expect { described_class.decode_payload("x", verify_expiration: true) }.to raise_error(NoMethodError, /private method 'decode_payload'/)
        expect { described_class.typed_claims({ "sub" => "victim" }, expected_type: "access") }
          .to raise_error(NoMethodError, /private method 'typed_claims'/)
      end
    end

    it "keeps config public because specs read real settings through it" do
      expect { described_class.config }.not_to raise_error
    end
  end
end
