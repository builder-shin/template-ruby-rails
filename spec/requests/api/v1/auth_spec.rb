# frozen_string_literal: true

require "rails_helper"
require "database_cleaner/active_record"

RSpec.describe "Api::V1::Auth", type: :request do
  def register_body(email:, password:, type: "users")
    { data: { type: type, attributes: { email: email, password: password } } }.to_json
  end

  def login_body(email:, password:, type: "authCredentials")
    { data: { type: type, attributes: { email: email, password: password } } }.to_json
  end

  def refresh_token_body(token, type: "refreshTokens")
    { data: { type: type, attributes: { refreshToken: token } } }.to_json
  end

  def expect_error(status:, code:)
    expect(response).to have_http_status(status)
    expect(response.headers.fetch("Content-Type")).to eq(JsonapiRequestHelper::JSONAPI_MEDIA_TYPE)
    expect(parsed_body.fetch("errors").first).to include("status" => Rack::Utils.status_code(status).to_s, "code" => code)
  end

  def register!(email:, password: "correct-horse-battery")
    post "/api/v1/auth/register", params: register_body(email: email, password: password), headers: jsonapi_headers
  end

  def login!(email:, password:)
    post "/api/v1/auth/login", params: login_body(email: email, password: password), headers: jsonapi_headers
  end

  describe "POST /api/v1/auth/register" do
    let(:email) { "New.User+tag@Example.com" }
    let(:password) { "correct-horse-battery" }

    it "creates a user, returns 201 with Location: /api/v1/users/me, and never echoes the password" do
      register!(email: email, password: password)

      expect(response).to have_http_status(:created)
      expect(response.headers.fetch("Content-Type")).to eq(JsonapiRequestHelper::JSONAPI_MEDIA_TYPE)
      expect(response.headers.fetch("Location")).to eq("/api/v1/users/me")

      resource = parsed_body.fetch("data")
      user = User.find_by!(email: "new.user+tag@example.com")
      aggregate_failures do
        expect(resource.fetch("type")).to eq("users")
        expect(resource.fetch("id")).to eq(user.id)
        expect(resource.dig("attributes", "email")).to eq("new.user+tag@example.com")
        expect(resource.dig("attributes", "isActive")).to be(true)
        expect(resource.dig("links", "self")).to eq("/api/v1/users/me")
      end
      expect(response.body).not_to include("password", password, user.password_hash)
    end

    it "persists an argon2 hash, not the raw password" do
      register!(email: email, password: password)

      user = User.find_by!(email: "new.user+tag@example.com")
      expect(user.password_hash).to start_with("$argon2id$")
      expect(Auth::Passwords.verify_password(password, user.password_hash)).to be(true)
    end

    it "rejects a duplicate registration with 409 EMAIL_ALREADY_REGISTERED, driven by the database unique index" do
      register!(email: "duplicate@example.com", password: password)

      expect do
        register!(email: "DUPLICATE@example.com  ".strip, password: "another-password-123")
      end.not_to change(User, :count)
      expect_error(status: 409, code: "EMAIL_ALREADY_REGISTERED")
    end

    # 스펙 6.7: 무조건 RecordNotUnique를 EMAIL_ALREADY_REGISTERED로 바꾸면 다른
    # 유니크 위반도 "이메일 중복"으로 잘못 보고된다. register가 실제로 일으킬 수
    # 있는 유니크 위반은 users.email 하나뿐이라(다른 유니크 컬럼이 없다) 이
    # 갈래를 실제 DB 상태만으로는 재현할 수 없다 — 그래서 User.create!가
    # *다른* 제약 이름을 진단 필드에 실은 RecordNotUnique를 던지도록 흉내 낸다.
    #
    # 처음에는 이 테스트를 `allow_any_instance_of(...).to
    # receive(:email_uniqueness_violation?).and_return(false)`로 썼었다 — 그런데
    # 그건 검증 대상 메서드 자체를 통째로 바꿔치기하는 것이라, 그 메서드의 실제
    # 구현(제약 이름 비교)이 조금이라도 바뀌어도 이 테스트는 절대 못 잡는다.
    # 실측: `email_uniqueness_violation?`을 "인자와 무관하게 true"로 뮤테이션해도
    # (즉 무조건 변환) 위 스텁 버전은 0 failures로 살아남았다 — 이름만 "constraint
    # name을 확인한다"이고 실제로는 그 메서드를 아예 실행하지 않는 가짜 가드였다.
    # 아래는 `.cause`(PG::UniqueViolation)와 그 `.result`(PG::Result#error_field)를
    # 실제 인터페이스에 맞춰 흉내 내어, `email_uniqueness_violation?`의 진짜 구현이
    # 돌면서 스스로 false를 내리게 만든다.
    it "falls back to the default RESOURCE_CONFLICT when the unique violation is not the email constraint" do
      create(:user, email: "duplicate@example.com")
      fake_pg_result = instance_double(PG::Result, error_field: "some_other_unique_index")
      fake_pg_cause = instance_double(PG::UniqueViolation, result: fake_pg_result)
      other_violation = ActiveRecord::RecordNotUnique.new("duplicate key value violates a different constraint")
      allow(other_violation).to receive(:cause).and_return(fake_pg_cause)
      allow(User).to receive(:create!).and_raise(other_violation)

      register!(email: "duplicate@example.com", password: password)

      expect_error(status: 409, code: "RESOURCE_CONFLICT")
    end

    it "rejects data.type other than users with 409 TYPE_MISMATCH" do
      post "/api/v1/auth/register", params: register_body(email: email, password: password, type: "authCredentials"),
                                     headers: jsonapi_headers

      expect_error(status: 409, code: "TYPE_MISMATCH")
      expect(parsed_body.dig("errors", 0, "source")).to eq("pointer" => "/data/type")
    end

    it "rejects an attribute outside {email, password} with 400 INVALID_JSONAPI_DOCUMENT" do
      body = { data: { type: "users", attributes: { email: email, password: password, isActive: true } } }.to_json

      post "/api/v1/auth/register", params: body, headers: jsonapi_headers

      expect_error(status: 400, code: "INVALID_JSONAPI_DOCUMENT")
      expect(parsed_body.dig("errors", 0, "source")).to eq("pointer" => "/data/attributes/isActive")
    end

    it "rejects a relationships member with 400 INVALID_JSONAPI_DOCUMENT (this resource has none)" do
      body = {
        data: {
          type: "users",
          attributes: { email: email, password: password },
          relationships: { workspace: { data: nil } }
        }
      }.to_json

      post "/api/v1/auth/register", params: body, headers: jsonapi_headers

      expect_error(status: 400, code: "INVALID_JSONAPI_DOCUMENT")
      expect(parsed_body.dig("errors", 0, "source")).to eq("pointer" => "/data/relationships/workspace")
    end

    # 실측(POST /api/v1/examples에 201자 title): 기존 쓰기 라우트도 속성 값
    # 위반에 422 VALIDATION_ERROR + /data/attributes/<field> pointer를 낸다 —
    # 그 값을 그대로 고정한다.
    it "rejects a password shorter than 12 or longer than 128 with 422 VALIDATION_ERROR" do
      aggregate_failures do
        register!(email: email, password: "x" * 11)
        expect_error(status: 422, code: "VALIDATION_ERROR")
        expect(parsed_body.dig("errors", 0, "source")).to eq("pointer" => "/data/attributes/password")

        register!(email: "other-#{email}", password: "x" * 129)
        expect_error(status: 422, code: "VALIDATION_ERROR")
        expect(parsed_body.dig("errors", 0, "source")).to eq("pointer" => "/data/attributes/password")
      end
    end

    it "accepts a password at exactly the 12 and 128 boundaries" do
      aggregate_failures do
        register!(email: "min-#{email}", password: "x" * 12)
        expect(response).to have_http_status(:created)

        register!(email: "max-#{email}", password: "x" * 128)
        expect(response).to have_http_status(:created)
      end
    end

    it "rejects an email longer than 254 characters with 422 VALIDATION_ERROR" do
      long_email = "#{'a' * 243}@example.com" # 243 + 12 = 255
      expect(long_email.length).to eq(255)

      register!(email: long_email, password: password)

      expect_error(status: 422, code: "VALIDATION_ERROR")
      expect(parsed_body.dig("errors", 0, "source")).to eq("pointer" => "/data/attributes/email")
    end

    it "rejects a non-JSON:API document shape (data not an object) with 400 INVALID_JSONAPI_DOCUMENT" do
      post "/api/v1/auth/register", params: { data: "oops" }.to_json, headers: jsonapi_headers

      expect_error(status: 400, code: "INVALID_JSONAPI_DOCUMENT")
    end

    describe "concurrent registration with the same email (real PostgreSQL unique index)" do
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

      # 스펙 6.7이 막으려는 바로 그 경합: 조회 후 삽입 사이의 창이 있으면 두
      # 요청이 둘 다 통과한다. 사전 조회가 전혀 없다는 것(유니크 인덱스만이
      # 유일한 방어선이라는 것)은 순차 테스트로는 증명할 수 없다 — 두 요청을
      # 진짜로 동시에 보내야 한다. refresh_sessions_spec.rb의 동시성 테스트와
      # 같은 패턴(barrier + 실제 스레드 + 별도 커넥션).
      it "lets exactly one of two simultaneous registrations with the same email succeed" do
        email = "race-#{SecureRandom.hex(8)}@example.com"
        barrier = Concurrent::CyclicBarrier.new(2)
        results = Queue.new

        @threads = 2.times.map do |i|
          Thread.new do
            ActiveRecord::Base.connection_pool.with_connection do
              session = ActionDispatch::Integration::Session.new(Rails.application)
              barrier.wait
              session.post(
                "/api/v1/auth/register",
                params: register_body(email: email, password: "password-#{i}-123456"),
                headers: jsonapi_headers
              )
              results << [ session.response.status, session.response.body ]
            end
          end
        end
        outcomes = @threads.map { results.pop }

        statuses = outcomes.map(&:first).sort
        aggregate_failures do
          expect(statuses).to eq([ 201, 409 ])
          conflict_body = JSON.parse(outcomes.find { |status, _| status == 409 }.last)
          expect(conflict_body.dig("errors", 0, "code")).to eq("EMAIL_ALREADY_REGISTERED")
          expect(User.where(email: email).count).to eq(1)
        end
      end
    end
  end

  describe "POST /api/v1/auth/login" do
    it "returns 200 with an authTokens document (id = refresh jti, no self link)" do
      register!(email: "login@example.com", password: "correct-horse-battery")

      login!(email: "login@example.com", password: "correct-horse-battery")

      expect(response).to have_http_status(:ok)
      expect(response.headers.fetch("Content-Type")).to eq(JsonapiRequestHelper::JSONAPI_MEDIA_TYPE)
      resource = parsed_body.fetch("data")
      session = RefreshSession.find(resource.fetch("id"))
      attributes = resource.fetch("attributes")
      aggregate_failures do
        expect(resource.fetch("type")).to eq("authTokens")
        expect(attributes.fetch("tokenType")).to eq("Bearer")
        expect(attributes.fetch("expiresIn")).to eq(Auth::Tokens.config.access_expires_seconds)
        expect(attributes.fetch("refreshExpiresIn")).to eq(Auth::Tokens.config.refresh_expires_seconds)
        expect(Auth::Tokens.hash_refresh_token(attributes.fetch("refreshToken"))).to eq(session.token_hash)
        expect(Auth::Tokens.decode(attributes.fetch("accessToken"), expected_type: "access").sub).to eq(session.user_id)
        expect(resource).not_to have_key("links")
      end
      expect(response.body).not_to include("correct-horse-battery")
    end

    # 순서 테스트 1/2 (스펙 6.5): 존재하지 않는 이메일과, 존재하는 이메일 +
    # 틀린 비밀번호가 같은 코드를 낸다. 이 테스트 하나만으로는 dummy 해시
    # 검증이 빠져도 통과한다(아래 뮤테이션 절 참고) — 그래서 아래에 dummy_hash
    # 호출 자체를 구조적으로 고정하는 테스트를 별도로 둔다.
    it "returns the same 401 INVALID_CREDENTIALS for a nonexistent email and a wrong password on a real account" do
      register!(email: "real@example.com", password: "correct-horse-battery")

      login!(email: "nobody-at-all@example.com", password: "whatever-password")
      expect_error(status: 401, code: "INVALID_CREDENTIALS")

      login!(email: "real@example.com", password: "wrong-password-123")
      expect_error(status: 401, code: "INVALID_CREDENTIALS")
    end

    # 이 테스트가 없으면 dummy_hash 호출 제거가 어떤 기능 테스트로도 안
    # 잡힌다(타이밍 부작용은 상태 코드 단언으로는 원천적으로 못 본다) — 최소한
    # "호출은 됐다"는 구조적 사실만이라도 고정해 둔다. 실제 시간 동등성은
    # spec/lib/auth/passwords_spec.rb가 Auth::Passwords 레벨에서 이미 고정한다.
    it "verifies against Auth::Passwords.dummy_hash even when the email does not exist" do
      expect(Auth::Passwords).to receive(:dummy_hash).and_call_original

      login!(email: "nobody-at-all@example.com", password: "whatever-password")

      expect_error(status: 401, code: "INVALID_CREDENTIALS")
    end

    it "does not call dummy_hash when the account exists" do
      register!(email: "real2@example.com", password: "correct-horse-battery")
      expect(Auth::Passwords).not_to receive(:dummy_hash)

      login!(email: "real2@example.com", password: "correct-horse-battery")

      expect(response).to have_http_status(:ok)
    end

    # 순서 테스트 2 (스펙 6.5) — 이것이 순서 계약의 진짜 가드다. 활성 여부를
    # 비밀번호보다 먼저 보면 이 테스트만 깨진다(아래 뮤테이션 절에서 실측).
    it "returns 401 INVALID_CREDENTIALS, not 403 USER_INACTIVE, for a wrong password on an inactive account" do
      register!(email: "inactive@example.com", password: "correct-horse-battery")
      User.find_by!(email: "inactive@example.com").update!(is_active: false)

      login!(email: "inactive@example.com", password: "totally-wrong-password")

      expect_error(status: 401, code: "INVALID_CREDENTIALS")
    end

    it "returns 403 USER_INACTIVE for the correct password on an inactive account" do
      register!(email: "inactive2@example.com", password: "correct-horse-battery")
      User.find_by!(email: "inactive2@example.com").update!(is_active: false)

      login!(email: "inactive2@example.com", password: "correct-horse-battery")

      expect_error(status: 403, code: "USER_INACTIVE")
    end

    # Step 3: 저장 직전(register)과 조회 직전(login)이 같은 정규화를 쓰지
    # 않으면 가입한 이메일로 로그인이 안 되는 상태가 생긴다.
    it "logs in with a normalized email even though registration used mixed case and surrounding whitespace" do
      register!(email: "  MiXed.Case@EXAMPLE.com  ", password: "correct-horse-battery")

      login!(email: "mixed.case@example.com", password: "correct-horse-battery")

      expect(response).to have_http_status(:ok)
    end

    it "rejects data.type other than authCredentials with 409 TYPE_MISMATCH" do
      post "/api/v1/auth/login",
           params: login_body(email: "x@example.com", password: "correct-horse-battery", type: "users"),
           headers: jsonapi_headers

      expect_error(status: 409, code: "TYPE_MISMATCH")
    end

    it "rejects a password shorter than 12 or an email over 254 characters with 422 VALIDATION_ERROR" do
      aggregate_failures do
        login!(email: "someone@example.com", password: "short")
        expect_error(status: 422, code: "VALIDATION_ERROR")
        expect(parsed_body.dig("errors", 0, "source")).to eq("pointer" => "/data/attributes/password")

        login!(email: "#{'a' * 243}@example.com", password: "correct-horse-battery")
        expect_error(status: 422, code: "VALIDATION_ERROR")
        expect(parsed_body.dig("errors", 0, "source")).to eq("pointer" => "/data/attributes/email")
      end
    end
  end

  describe "POST /api/v1/auth/refresh" do
    def issued_refresh_token(email: "refresher@example.com", password: "correct-horse-battery")
      register!(email: email, password: password)
      login!(email: email, password: password)
      parsed_body.dig("data", "attributes", "refreshToken")
    end

    it "rotates a valid refresh token and returns a new authTokens document" do
      old_token = issued_refresh_token

      post "/api/v1/auth/refresh", params: refresh_token_body(old_token), headers: jsonapi_headers

      expect(response).to have_http_status(:ok)
      new_token = parsed_body.dig("data", "attributes", "refreshToken")
      expect(new_token).not_to eq(old_token)
    end

    # TOKEN_REVOKED는 이 태스크가 처음으로 실제 HTTP 라우트에 연결한다(Task
    # 3에는 아직 호출자가 없었다) — 재사용 감지가 끝까지 배선됐는지 여기서
    # 확인한다.
    it "returns 401 TOKEN_REVOKED when a rotated (already-used) refresh token is replayed" do
      old_token = issued_refresh_token

      post "/api/v1/auth/refresh", params: refresh_token_body(old_token), headers: jsonapi_headers
      expect(response).to have_http_status(:ok)

      post "/api/v1/auth/refresh", params: refresh_token_body(old_token), headers: jsonapi_headers

      expect_error(status: 401, code: "TOKEN_REVOKED")
    end

    it "returns 403 USER_INACTIVE when the account was deactivated after the token was issued" do
      token = issued_refresh_token(email: "deactivated@example.com")
      User.find_by!(email: "deactivated@example.com").update!(is_active: false)

      post "/api/v1/auth/refresh", params: refresh_token_body(token), headers: jsonapi_headers

      expect_error(status: 403, code: "USER_INACTIVE")
    end

    it "returns 401 INVALID_TOKEN for garbage input" do
      post "/api/v1/auth/refresh", params: refresh_token_body("not-a-jwt"), headers: jsonapi_headers

      expect_error(status: 401, code: "INVALID_TOKEN")
    end

    # 팀장 메모: Auth::Tokens.decode_payload가 문자열이 아닌 토큰을 InvalidToken으로
    # 거절하고, Auth::RefreshSessions가 그걸 이미 Failure(401, INVALID_TOKEN)로
    # 바꿔 반환한다 — 컨트롤러가 refreshToken의 타입을 따로 검사하지 않아도
    # 500 대신 깨끗한 401이 나오는지 확인한다.
    it "returns 401 INVALID_TOKEN, not 500, when refreshToken is not a string" do
      post "/api/v1/auth/refresh", params: { data: { type: "refreshTokens", attributes: { refreshToken: 123 } } }.to_json,
                                    headers: jsonapi_headers

      expect_error(status: 401, code: "INVALID_TOKEN")
    end

    it "rejects data.type other than refreshTokens with 409 TYPE_MISMATCH" do
      post "/api/v1/auth/refresh", params: refresh_token_body("whatever", type: "authCredentials"),
                                    headers: jsonapi_headers

      expect_error(status: 409, code: "TYPE_MISMATCH")
    end

    # 이 describe 밖의 모든 refresh 테스트는 RSpec의 기본 트랜잭션 픽스처
    # (use_transactional_tests = true) 아래서 돈다 — 매 예제가 이미 RSpec이 열어
    # 둔 트랜잭션 "안"이라 `ActiveRecord::Base.connection.transaction_open?`이
    # 컨트롤러가 스스로 트랜잭션을 여는지와 무관하게 항상 true다
    # (refresh_sessions_spec.rb의 "F1" 코멘트가 말하는 것과 같은 함정). 실측:
    # AuthController#refresh에서 `ActiveRecord::Base.transaction do ... end`
    # 래핑을 지워도 위의 6개 테스트는 전부 그대로 통과했다 — 그 상태로는 이
    # 파일이 컨트롤러가 실제로 트랜잭션을 여는지 전혀 증명하지 못한다는 뜻이다.
    # 여기서만 픽스처를 끄고 실제 커넥션으로 검증한다.
    describe "opens its own transaction (independent of RSpec's ambient one)" do
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

      it "rotates successfully with no ambient RSpec transaction open" do
        email = "no-ambient-tx-#{SecureRandom.hex(4)}@example.com"
        register!(email: email, password: "correct-horse-battery")
        login!(email: email, password: "correct-horse-battery")
        old_token = parsed_body.dig("data", "attributes", "refreshToken")

        post "/api/v1/auth/refresh", params: refresh_token_body(old_token), headers: jsonapi_headers

        expect(response).to have_http_status(:ok)
      end
    end
  end

  describe "POST /api/v1/auth/logout" do
    def issued_refresh_token(email: "loggerouter@example.com", password: "correct-horse-battery")
      register!(email: email, password: password)
      login!(email: email, password: password)
      parsed_body.dig("data", "attributes", "refreshToken")
    end

    it "returns 204 with no body and revokes the session" do
      token = issued_refresh_token

      post "/api/v1/auth/logout", params: refresh_token_body(token), headers: jsonapi_headers

      expect(response).to have_http_status(:no_content)
      expect(response.body).to be_empty
      claims = Auth::Tokens.decode(token, expected_type: "refresh")
      expect(RefreshSession.find(claims.jti).revoked_at).to be_present
    end

    it "is idempotent -- logging out twice with the same token still returns 204" do
      token = issued_refresh_token

      post "/api/v1/auth/logout", params: refresh_token_body(token), headers: jsonapi_headers
      expect(response).to have_http_status(:no_content)

      post "/api/v1/auth/logout", params: refresh_token_body(token), headers: jsonapi_headers

      expect(response).to have_http_status(:no_content)
    end

    it "returns 401 INVALID_TOKEN for garbage input" do
      post "/api/v1/auth/logout", params: refresh_token_body("not-a-jwt"), headers: jsonapi_headers

      expect_error(status: 401, code: "INVALID_TOKEN")
    end

    it "returns 401 INVALID_TOKEN, not 500, when refreshToken is not a string" do
      post "/api/v1/auth/logout", params: { data: { type: "refreshTokens", attributes: { refreshToken: [ 1, 2 ] } } }.to_json,
                                   headers: jsonapi_headers

      expect_error(status: 401, code: "INVALID_TOKEN")
    end

    # refresh와 같은 이유(위 "opens its own transaction" 코멘트 참고) — 이
    # describe 밖의 logout 테스트는 RSpec의 기본 트랜잭션 픽스처 아래서 돌아
    # `AuthController#logout`이 스스로 트랜잭션을 여는지 증명하지 못한다.
    describe "opens its own transaction (independent of RSpec's ambient one)" do
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

      it "logs out successfully with no ambient RSpec transaction open" do
        email = "no-ambient-tx-logout-#{SecureRandom.hex(4)}@example.com"
        register!(email: email, password: "correct-horse-battery")
        login!(email: email, password: "correct-horse-battery")
        token = parsed_body.dig("data", "attributes", "refreshToken")

        post "/api/v1/auth/logout", params: refresh_token_body(token), headers: jsonapi_headers

        expect(response).to have_http_status(:no_content)
      end
    end
  end

  describe "content negotiation is inherited (ApplicationController -> JsonapiNegotiation)" do
    it "returns 415 for a non-JSON:API Content-Type on POST /auth/login" do
      post "/api/v1/auth/login",
           params: login_body(email: "x@example.com", password: "correct-horse-battery"),
           headers: jsonapi_headers.merge("CONTENT_TYPE" => "application/json")

      expect_error(status: 415, code: "UNSUPPORTED_MEDIA_TYPE")
    end
  end
end
