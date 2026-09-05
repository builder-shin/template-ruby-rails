# frozen_string_literal: true

require "rails_helper"
require "base64"
require "openssl"
require "database_cleaner/active_record"

RSpec.describe Auth::RefreshSessions do
  let(:user) { create(:user) }

  # rotate/logout 둘 다 "트랜잭션은 호출자가 소유한다"는 계약이다(refresh_sessions.rb
  # 모듈 코멘트 참고) — Task 3에는 아직 그 호출자(컨트롤러, Task 4/5)가 없으므로
  # 스펙이 그 역할을 대신 흉내 낸다. 매 호출을 명시적으로 트랜잭션으로 감싸서, 실패
  # 갈래에서도 그 안의 변경(재사용 감지의 일괄 폐기 등)이 정상적으로 "커밋"됨을
  # 재현한다.
  def in_transaction
    ActiveRecord::Base.transaction { return yield }
  end

  def issue_pair_for(target_user)
    in_transaction { described_class.issue_for_locked_user(target_user) }
  end

  # 서명은 진짜 비밀키로 하되 payload를 직접 짜서 decode 쪽 방어 로직을 시험한다.
  # tokens_spec.rb의 raw_token/valid_payload와 같은 패턴이다.
  def raw_token(payload, secret: Auth::Tokens.config.secret_key)
    header = { "alg" => "HS256", "typ" => "JWT" }
    segments = [ header, payload ].map { |part| Base64.urlsafe_encode64(JSON.generate(part), padding: false) }
    signature = OpenSSL::HMAC.digest("SHA256", secret, segments.join("."))
    (segments + [ Base64.urlsafe_encode64(signature, padding: false) ]).join(".")
  end

  def valid_refresh_payload(overrides = {})
    now = Time.now.to_i
    {
      "sub" => SecureRandom.uuid,
      "jti" => SecureRandom.uuid,
      "type" => "refresh",
      "iat" => now,
      "exp" => now + Auth::Tokens.config.refresh_expires_seconds,
      "iss" => Auth::Tokens.config.issuer,
      "aud" => Auth::Tokens.config.audience
    }.merge(overrides)
  end

  # 서명은 유효하지만(진짜 비밀키로 만들었지만) JWT 자체의 exp가 이미 지난 refresh
  # 토큰을 만든다. refresh_sessions 행의 expires_at은 별도로 통제할 수 있게 이
  # 헬퍼는 토큰만 만들고 행은 호출부가 만든다 — 4번 갈래(만료)의 "JWT가 만료됐거나
  # OR 세션 행이 만료됐거나" 두 축을 독립적으로 시험하려면 이 둘이 갈라져야 한다.
  def build_expired_refresh_token(target_user, session_id:)
    long_ago = Time.at(Time.now.to_i - Auth::Tokens.config.refresh_expires_seconds - 10.days.to_i).utc
    Auth::Tokens.create(target_user.id, type: "refresh", jti: session_id, now: long_ago)
  end

  describe ".issue_for_locked_user" do
    it "creates a refresh_sessions row keyed by the pair's id, hashing the refresh token into token_hash" do
      pair = issue_pair_for(user)

      session = RefreshSession.find(pair.id)
      aggregate_failures do
        expect(session.user_id).to eq(user.id)
        expect(session.token_hash).to eq(Auth::Tokens.hash_refresh_token(pair.refresh_token))
        expect(session.revoked_at).to be_nil
        expect(session.replaced_by_id).to be_nil
      end
    end

    it "issues access and refresh tokens for this user, with the refresh token's jti equal to the pair id" do
      pair = issue_pair_for(user)

      access_claims = Auth::Tokens.decode(pair.access_token, expected_type: "access")
      refresh_claims = Auth::Tokens.decode(pair.refresh_token, expected_type: "refresh")

      aggregate_failures do
        expect(access_claims.sub).to eq(user.id)
        expect(refresh_claims.sub).to eq(user.id)
        expect(refresh_claims.jti).to eq(pair.id)
      end
    end

    it "reports Bearer token_type and the configured access/refresh lifetimes" do
      pair = issue_pair_for(user)

      aggregate_failures do
        expect(pair.token_type).to eq("Bearer")
        expect(pair.expires_in).to eq(Auth::Tokens.config.access_expires_seconds)
        expect(pair.refresh_expires_in).to eq(Auth::Tokens.config.refresh_expires_seconds)
      end
    end

    it "sets refresh_sessions.expires_at to exactly the refresh token's exp claim" do
      pair = issue_pair_for(user)

      refresh_claims = Auth::Tokens.decode(pair.refresh_token, expected_type: "refresh")
      session = RefreshSession.find(pair.id)

      expect(session.expires_at).to eq(refresh_claims.exp)
    end

    it "does not check whether the user is active -- that is the caller's responsibility, not this method's" do
      inactive_user = create(:user, is_active: false)

      expect { issue_pair_for(inactive_user) }.not_to raise_error
    end
  end

  describe ".rotate" do
    it "on normal rotation: revokes the old session, links replaced_by_id to the new one, and returns a working new pair" do
      old_pair = issue_pair_for(user)

      new_pair = in_transaction { described_class.rotate(old_pair.refresh_token) }

      old_session = RefreshSession.find(old_pair.id)
      aggregate_failures do
        expect(new_pair).to be_a(described_class::TokenPair)
        expect(new_pair.id).not_to eq(old_pair.id)
        expect(old_session.revoked_at).to be_present
        expect(old_session.replaced_by_id).to eq(new_pair.id)
        expect(RefreshSession.find(new_pair.id).revoked_at).to be_nil
        expect(Auth::Tokens.decode(new_pair.refresh_token, expected_type: "refresh").sub).to eq(user.id)
      end
    end

    describe "lock order (F3)" do
      it "locks the users row before the refresh_sessions row" do
        # 이 코멘트대로 코드가 실제로 동작하는지 SQL을 직접 엿듣지 않고는 확인할 길이
        # 없다 -- 순서를 반대로 바꿔도(세션 먼저, 사용자 나중) 23개 기존 예제가 전부
        # 그대로 통과한다는 것이 팀장 재현으로 이미 확인됐다: 이 모듈의 진입점이
        # 하나뿐이라 자기 자신과는 교착하지 않기 때문이다. `sql.active_record`
        # 알림을 구독해 실제로 나간 쿼리 순서를 본다.
        pair = issue_pair_for(user)
        queries = []
        subscriber = ActiveSupport::Notifications.subscribe("sql.active_record") do |*, payload|
          queries << payload[:sql]
        end

        begin
          in_transaction { described_class.rotate(pair.refresh_token) }
        ensure
          ActiveSupport::Notifications.unsubscribe(subscriber)
        end

        user_lock_index = queries.index { |sql| sql.match?(/FROM\s+"users".*FOR UPDATE/) }
        session_lock_index = queries.index { |sql| sql.match?(/FROM\s+"refresh_sessions".*FOR UPDATE/) }
        context = "captured queries:\n#{queries.each_with_index.map { |q, i| "  [#{i}] #{q}" }.join("\n")}"

        aggregate_failures do
          expect(user_lock_index).not_to(be_nil, -> { "no `users ... FOR UPDATE` query found.\n#{context}" })
          expect(session_lock_index).not_to(be_nil, -> { "no `refresh_sessions ... FOR UPDATE` query found.\n#{context}" })
          expect(user_lock_index).to(be < session_lock_index, -> { "users lock did not precede refresh_sessions lock.\n#{context}" })
        end
      end
    end

    describe "reuse detection" do
      it "revokes every OTHER active session of the same user, leaves another user's session alone, and returns TOKEN_REVOKED" do
        pair = issue_pair_for(user)
        replayed_session = RefreshSession.find(pair.id)
        replayed_session.update!(revoked_at: 1.hour.ago) # 이 토큰은 이미 한 번 회전(또는 로그아웃)됐다고 가정한다

        # 이 사용자의 "진짜" 활성 세션 -- 재사용 감지가 쓸어가야 하는 대상.
        other_session_same_user = create(:refresh_session, user: user)

        # 다른 사용자의 활성 세션 -- 절대 건드리면 안 된다. 일부러 별도 사용자·
        # 별도 세션으로 만든다 (두 세계가 우연히 같아져 가드가 아무것도 지키지
        # 못하는 함정을 피하기 위해 -- 이 프로젝트에서 세 번 반복된 실수다).
        other_user = create(:user)
        other_users_session = create(:refresh_session, user: other_user)

        result = in_transaction { described_class.rotate(pair.refresh_token) }

        aggregate_failures do
          expect(result).to eq(described_class::Failure.new(status: 401, code: "TOKEN_REVOKED"))
          expect(other_session_same_user.reload.revoked_at).to be_present
          expect(other_users_session.reload.revoked_at).to be_nil
        end
      end
    end

    describe "inactive user" do
      it "revokes only the presented session (not the user's other sessions) and returns USER_INACTIVE" do
        inactive_user = create(:user, is_active: false)
        pair = in_transaction { described_class.issue_for_locked_user(inactive_user) }
        untouched_sibling = create(:refresh_session, user: inactive_user)

        result = in_transaction { described_class.rotate(pair.refresh_token) }

        aggregate_failures do
          expect(result).to eq(described_class::Failure.new(status: 403, code: "USER_INACTIVE"))
          expect(RefreshSession.find(pair.id).revoked_at).to be_present
          expect(untouched_sibling.reload.revoked_at).to be_nil
        end
      end
    end

    describe "expiry has two independent triggers" do
      it "revokes the session and returns TOKEN_EXPIRED when the JWT itself is expired, even though the session row's expires_at is still in the future" do
        session_id = SecureRandom.uuid
        expired_token = build_expired_refresh_token(user, session_id: session_id)
        session = create(:refresh_session, id: session_id, user: user,
                                            token_hash: Auth::Tokens.hash_refresh_token(expired_token),
                                            expires_at: 1.day.from_now)

        result = in_transaction { described_class.rotate(expired_token) }

        aggregate_failures do
          expect(result).to eq(described_class::Failure.new(status: 401, code: "TOKEN_EXPIRED"))
          expect(session.reload.revoked_at).to be_present
        end
      end

      it "revokes the session and returns TOKEN_EXPIRED when only the session row's expires_at has passed, even though the JWT itself is still live" do
        pair = issue_pair_for(user)
        RefreshSession.find(pair.id).update_columns(expires_at: 1.minute.ago)

        result = in_transaction { described_class.rotate(pair.refresh_token) }

        aggregate_failures do
          expect(result).to eq(described_class::Failure.new(status: 401, code: "TOKEN_EXPIRED"))
          expect(RefreshSession.find(pair.id).revoked_at).to be_present
        end
      end

      it "keeps revoked_at at its first value across repeated attempts with an already-expired token" do
        session_id = SecureRandom.uuid
        expired_token = build_expired_refresh_token(user, session_id: session_id)
        create(:refresh_session, id: session_id, user: user,
                                  token_hash: Auth::Tokens.hash_refresh_token(expired_token),
                                  expires_at: 1.day.from_now)

        in_transaction { described_class.rotate(expired_token) }
        first_revoked_at = RefreshSession.find(session_id).revoked_at

        in_transaction { described_class.rotate(expired_token) }

        expect(RefreshSession.find(session_id).revoked_at).to eq(first_revoked_at)
      end
    end

    describe "signature is broken" do
      it "returns INVALID_TOKEN and touches no session" do
        pair = issue_pair_for(user)
        tampered = pair.refresh_token[0..-5] + (pair.refresh_token[-4..] == "aaaa" ? "bbbb" : "aaaa")

        result = in_transaction { described_class.rotate(tampered) }

        aggregate_failures do
          expect(result).to eq(described_class::Failure.new(status: 401, code: "INVALID_TOKEN"))
          expect(RefreshSession.find(pair.id).revoked_at).to be_nil
        end
      end

      it "also rejects nil and an empty string without raising" do
        aggregate_failures do
          expect(in_transaction { described_class.rotate(nil) })
            .to eq(described_class::Failure.new(status: 401, code: "INVALID_TOKEN"))
          expect(in_transaction { described_class.rotate("") })
            .to eq(described_class::Failure.new(status: 401, code: "INVALID_TOKEN"))
        end
      end
    end

    describe "no session exists for the token's jti" do
      it "returns INVALID_TOKEN" do
        unknown_token = Auth::Tokens.create(user.id, type: "refresh", jti: SecureRandom.uuid)

        result = in_transaction { described_class.rotate(unknown_token) }

        expect(result).to eq(described_class::Failure.new(status: 401, code: "INVALID_TOKEN"))
      end
    end

    describe "session exists but does not match the claims" do
      it "returns INVALID_TOKEN and touches nothing when token_hash does not match (token substitution)" do
        pair = issue_pair_for(user)
        # 같은 jti·같은 sub로 새로 서명한 토큰. `now:`를 명시적으로 몇 초 밀어야 한다 --
        # 그냥 Auth::Tokens.create(..., jti: pair.id)만 부르면 원래 토큰과 같은 초(iat)에
        # 만들어질 때가 있고, 그러면 sub·jti·iat·exp·iss·aud가 전부 같아 payload가
        # 완전히 같은 문자열로 서명되어 해시까지 우연히 같아진다 -- "치환된 토큰"이
        # 아니라 "같은 토큰을 두 번 만든 것"이 되어 이 테스트가 아무것도 검증하지
        # 못하게 된다(이 프로젝트에서 반복된 "두 세계가 우연히 같아지는" 함정과 같은
        # 종류다). now:를 강제로 다르게 줘서 iat/exp가 달라지게 하고, 그래서 바이트
        # 자체가 달라 저장된 token_hash와 반드시 어긋나게 만든다. sub/user_id는
        # 맞으므로 이 실패는 오직 hash 비교 쪽만 겨냥한다.
        substituted_token = Auth::Tokens.create(user.id, type: "refresh", jti: pair.id,
                                                          now: Time.at(Time.now.to_i + 5).utc)

        result = in_transaction { described_class.rotate(substituted_token) }

        aggregate_failures do
          expect(result).to eq(described_class::Failure.new(status: 401, code: "INVALID_TOKEN"))
          expect(RefreshSession.find(pair.id).revoked_at).to be_nil
        end
      end

      it "returns INVALID_TOKEN when the session belongs to a different user than claims.sub, even though token_hash matches exactly" do
        session_id = SecureRandom.uuid
        other_user = create(:user)
        crafted_token = Auth::Tokens.create(other_user.id, type: "refresh", jti: session_id)
        # token_hash는 이 정확한 토큰과 맞지만, 세션은 `other_user`가 아니라 `user`
        # 소유다 -- 이 실패는 오직 user_id/sub 비교 쪽만 겨냥한다.
        session = create(:refresh_session, id: session_id, user: user,
                                            token_hash: Auth::Tokens.hash_refresh_token(crafted_token))

        result = in_transaction { described_class.rotate(crafted_token) }

        aggregate_failures do
          expect(result).to eq(described_class::Failure.new(status: 401, code: "INVALID_TOKEN"))
          expect(session.reload.revoked_at).to be_nil
        end
      end

      it "returns INVALID_TOKEN, not a database error, when claims.sub is not shaped like a UUID at all" do
        token = raw_token(valid_refresh_payload("sub" => "not-a-uuid"))

        result = in_transaction { described_class.rotate(token) }

        expect(result).to eq(described_class::Failure.new(status: 401, code: "INVALID_TOKEN"))
      end
    end
  end

  describe ".logout" do
    it "revokes a valid session and returns nil" do
      pair = issue_pair_for(user)

      result = in_transaction { described_class.logout(pair.refresh_token) }

      aggregate_failures do
        expect(result).to be_nil
        expect(RefreshSession.find(pair.id).revoked_at).to be_present
      end
    end

    it "is idempotent: a second logout with the same token still returns nil and keeps the original revoked_at" do
      pair = issue_pair_for(user)

      in_transaction { described_class.logout(pair.refresh_token) }
      first_revoked_at = RefreshSession.find(pair.id).revoked_at

      result = in_transaction { described_class.logout(pair.refresh_token) }

      aggregate_failures do
        expect(result).to be_nil
        expect(RefreshSession.find(pair.id).revoked_at).to eq(first_revoked_at)
      end
    end

    it "does not touch the user's other sessions (unlike rotate's reuse detection)" do
      pair = issue_pair_for(user)
      sibling = create(:refresh_session, user: user)

      in_transaction { described_class.logout(pair.refresh_token) }

      expect(sibling.reload.revoked_at).to be_nil
    end

    it "returns TOKEN_EXPIRED and still revokes the session when the refresh token itself is expired" do
      session_id = SecureRandom.uuid
      expired_token = build_expired_refresh_token(user, session_id: session_id)
      create(:refresh_session, id: session_id, user: user,
                                token_hash: Auth::Tokens.hash_refresh_token(expired_token),
                                expires_at: 1.day.from_now)

      result = in_transaction { described_class.logout(expired_token) }

      aggregate_failures do
        expect(result).to eq(described_class::Failure.new(status: 401, code: "TOKEN_EXPIRED"))
        expect(RefreshSession.find(session_id).revoked_at).to be_present
      end
    end

    it "returns INVALID_TOKEN for a garbage token without touching anything" do
      result = in_transaction { described_class.logout("not-a-jwt") }

      expect(result).to eq(described_class::Failure.new(status: 401, code: "INVALID_TOKEN"))
    end
  end

  describe "concurrent rotation of the same refresh token (real PostgreSQL locking)" do
    self.use_transactional_tests = false

    before do
      ActiveRecord::Base.connection_handler.clear_active_connections!
      DatabaseCleaner.clean_with(:truncation)
    end

    after do
      @threads&.each { |thread| thread.join(5) }
      ActiveRecord::Base.connection_handler.clear_active_connections!
      DatabaseCleaner.clean_with(:truncation)
      ActiveRecord::Base.connection_handler.clear_active_connections!
    end

    it "lets exactly one of two simultaneous rotations win; the loser's reuse detection then revokes every active " \
       "session for that user, including the winner's brand-new one" do
      concurrent_user = create(:user)
      pair = ActiveRecord::Base.transaction { described_class.issue_for_locked_user(concurrent_user) }
      raw_refresh_token = pair.refresh_token

      barrier = Concurrent::CyclicBarrier.new(2)
      @threads = 2.times.map do
        Thread.new do
          ActiveRecord::Base.connection_pool.with_connection do
            barrier.wait
            ActiveRecord::Base.transaction { described_class.rotate(raw_refresh_token) }
          end
        end
      end
      results = @threads.map(&:value)

      successes = results.reject { |result| result.is_a?(described_class::Failure) }
      failures = results.select { |result| result.is_a?(described_class::Failure) }

      aggregate_failures do
        expect(successes.length).to eq(1)
        expect(failures.length).to eq(1)
        expect(failures.first.code).to eq("TOKEN_REVOKED")
        # `.lock`이 사용자 쪽이든 세션 쪽이든 실수로 빠지면, 두 스레드가 동시에
        # "아직 안 끊겼다"를 보고 각자 새 세션을 만들어 successes.length가 2가
        # 되고 아래 count도 1(둘 중 하나만 산다)이 된다 -- 이 두 값이 잠금이
        # 실재한다는 증거다. 진 쪽의 재사용 감지가 이긴 쪽의 새 세션까지 함께
        # 쓸어가므로 활성 세션은 결국 하나도 남지 않는 것이 옳다: 동시에 도착한
        # 같은 토큰은 정상 클라이언트의 재시도인지 탈취인지 구분할 수 없다.
        expect(RefreshSession.where(user_id: concurrent_user.id, revoked_at: nil).count).to eq(0)
      end
    end
  end

  # F1 (팀장 fix round 1): "트랜잭션은 호출자가 소유한다"는 계약이 모듈 코멘트에만
  # 적혀 있고 강제되지 않으면, 컨트롤러가 실수로 트랜잭션 밖에서 rotate/logout을
  # 부르는 순간 이 파일의 모든 보장(잠금·재사용 감지·원자적 회전)이 조용히
  # 사라진다 -- 에러도, 실패하는 테스트도 없이. 기본 트랜잭션 픽스처(`use_transactional_
  # tests = true`, rails_helper.rb) 아래서는 매 예제가 이미 RSpec이 열어 둔 트랜잭션
  # 안에서 돌므로 `transaction_open?`이 언제나 true다 -- 이 describe 블록 전체가
  # `use_transactional_tests = false`인 이유가 그것이다. 이걸 빼고 쓴 테스트는
  # 가드가 있든 없든 통과해서, 있어 보이지만 아무것도 지키지 않는 테스트가 된다.
  describe "the caller-owned-transaction contract is enforced (F1)" do
    self.use_transactional_tests = false

    before do
      ActiveRecord::Base.connection_handler.clear_active_connections!
      DatabaseCleaner.clean_with(:truncation)
    end

    after do
      ActiveRecord::Base.connection_handler.clear_active_connections!
      DatabaseCleaner.clean_with(:truncation)
      ActiveRecord::Base.connection_handler.clear_active_connections!
    end

    it "raises when rotate is called with no open transaction" do
      real_user = create(:user)
      pair = ActiveRecord::Base.transaction { described_class.issue_for_locked_user(real_user) }

      expect { described_class.rotate(pair.refresh_token) }
        .to raise_error(/caller must own the transaction/)
    end

    it "raises when logout is called with no open transaction" do
      real_user = create(:user)
      pair = ActiveRecord::Base.transaction { described_class.issue_for_locked_user(real_user) }

      expect { described_class.logout(pair.refresh_token) }
        .to raise_error(/caller must own the transaction/)
    end

    it "does not raise, and behaves normally, when the caller does wrap the call in a transaction" do
      real_user = create(:user)
      pair = ActiveRecord::Base.transaction { described_class.issue_for_locked_user(real_user) }

      result = nil
      expect { result = ActiveRecord::Base.transaction { described_class.rotate(pair.refresh_token) } }
        .not_to raise_error
      expect(result).to be_a(described_class::TokenPair)
    end
  end
end
