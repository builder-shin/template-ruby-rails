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

    it "rejects a garbage token string, an empty string, and nil without crashing" do
      aggregate_failures do
        expect { described_class.decode("not-a-jwt", expected_type: "access") }.to raise_error(Auth::Tokens::InvalidToken)
        expect { described_class.decode("", expected_type: "access") }.to raise_error(Auth::Tokens::InvalidToken)
        expect { described_class.decode(nil, expected_type: "access") }.to raise_error(Auth::Tokens::InvalidToken)
      end
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
end
