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

    # 정규화는 길이를 **늘린다** — `String#downcase(:fold)`(전체 유니코드 케이스
    # 폴딩)가 "ß"를 "ss"로 바꾼다. 길이 상한을 원본에만 걸면 이 입력은 상한을
    # 통과하고, 폴딩된 264자가 varchar(254)인 users.email에 INSERT되어 Postgres의
    # StringDataRightTruncation → rescue_from StandardError → **500**이 된다.
    # 무인증 공개 라우트가 요청 본문 하나로 500을 내는 갈래였다.
    #
    # 이 테스트가 형식 검증(아래 "rejects a syntactically invalid email")과
    # 우연히 같은 세계를 보지 않는다는 점이 중요하다. 그것을 구현 상수를
    # 들여다보지 않고 **동작으로** 고정한다: 같은 모양이되 짧은 주소는 201로
    # 가입된다 — 즉 긴 쪽이 거절되는 유일한 이유는 "정규화 후 길이"다.
    it "rejects an email that only exceeds 254 characters after case folding with 422, not 500" do
      raw = "#{'a' * 230}#{'ß' * 11}@example.com"
      folded = raw.strip.downcase(:fold)
      aggregate_failures do
        expect(raw.length).to eq(253)
        expect(folded.length).to eq(264)
      end

      register!(email: "#{'a' * 10}#{'ß' * 11}@example.com", password: password)
      expect(response).to have_http_status(:created)

      register!(email: raw, password: password)

      expect_error(status: 422, code: "VALIDATION_ERROR")
      expect(parsed_body.dig("errors", 0, "source")).to eq("pointer" => "/data/attributes/email")
    end

    # 정본은 `AuthEmail = Annotated[EmailStr, Field(max_length=254)]`로 형식까지
    # 본다 — 아래 값 전부 422다(정본의 pydantic 스키마를 직접 실행해 실측).
    # swagger_helper.rb도 email에 `format: "email"`을 이미 문서화해 두었다.
    it "rejects a syntactically invalid email with 422 VALIDATION_ERROR" do
      aggregate_failures do
        [ "not-an-email", "a b@c d", "a", "a@b", ".a@b.com", "a..b@c.com", "a@-b.com" ].each do |bad|
          expect do
            register!(email: bad, password: password)
          end.not_to change(User, :count)
          expect_error(status: 422, code: "VALIDATION_ERROR")
          expect(parsed_body.dig("errors", 0, "source")).to eq("pointer" => "/data/attributes/email")
        end
      end
    end

    # TLD가 전부 숫자인 도메인은 정본이 "globally deliverable이 아니다"로
    # 거절한다(실측: "The part after the @-sign is not valid. It is not within a
    # valid top-level domain."). 형식 정규식과는 별개의 판정이라 별도 테스트로
    # 둔다 — 두 가드를 각각 죽일 수 있어야 한다.
    it "rejects a domain whose top-level label is all digits with 422 VALIDATION_ERROR" do
      aggregate_failures do
        [ "a@b.1", "a@192.168.0.1" ].each do |bad|
          register!(email: bad, password: password)
          expect_error(status: 422, code: "VALIDATION_ERROR")
          expect(parsed_body.dig("errors", 0, "source")).to eq("pointer" => "/data/attributes/email")
        end
      end
    end

    # 1차 파동이 URI::MailTo::EMAIL_REGEXP(ASCII 전용)를 쓰는 바람에 정본이
    # 201로 받는 비ASCII 주소를 422로 거절했다 — 고치기 전보다 나쁜 상태였다.
    # 이 가드가 없으면 그 회귀가 조용히 다시 들어온다. 정본에서 아래 넷 전부
    # 201임을 직접 실행해 확인했다.
    it "accepts internationalized addresses the canonical accepts" do
      aggregate_failures do
        {
          "shørt@example.com" => "shørt@example.com",
          "user@éxample.com" => "user@éxample.com",
          "例え@example.com" => "例え@example.com",
          "Ünïcode@例え.テスト" => "ünïcode@例え.テスト"
        }.each do |raw, normalized|
          register!(email: raw, password: password)

          expect(response).to have_http_status(:created)
          expect(parsed_body.dig("data", "attributes", "email")).to eq(normalized)
        end
      end
    end

    # 쓰기 응답(JSON.generate)과 읽기 응답(render jsonapi:)이 같은 자원의 같은
    # 필드를 서로 다른 형식으로 내던 결함의 가드. `Time.iso8601` 파싱 성공만
    # 단언하면 정밀도 차이(.418 유무)를 못 잡으므로 **문자열이 정확히 같은지**를
    # 본다. 실측(고치기 전): 201이 "2026-09-05 23:49:08 +0900",
    # GET /users/me가 "2026-09-05T23:49:08.639+09:00" — 전자는 Time.iso8601이
    # ArgumentError를 낸다.
    it "renders createdAt/updatedAt exactly as the read path does for the same user" do
      register!(email: "isotime@example.com", password: password)
      expect(response).to have_http_status(:created)
      written = parsed_body.fetch("data").fetch("attributes")

      login!(email: "isotime@example.com", password: password)
      access_token = parsed_body.dig("data", "attributes", "accessToken")

      get "/api/v1/users/me", headers: jsonapi_headers.merge(auth_bearer_headers(access_token))

      expect(response).to have_http_status(:ok)
      read = parsed_body.fetch("data").fetch("attributes")
      aggregate_failures do
        expect(written.fetch("createdAt")).to eq(read.fetch("createdAt"))
        expect(written.fetch("updatedAt")).to eq(read.fetch("updatedAt"))
        expect { Time.iso8601(written.fetch("createdAt")) }.not_to raise_error
      end
    end

    it "rejects a non-JSON:API document shape (data not an object) with 400 INVALID_JSONAPI_DOCUMENT" do
      post "/api/v1/auth/register", params: { data: "oops" }.to_json, headers: jsonapi_headers

      expect_error(status: 400, code: "INVALID_JSONAPI_DOCUMENT")
    end

    # 위 테스트는 `data` 자체가 객체가 아닌 경우만 본다 — 멤버(attributes /
    # relationships)의 모양 검증은 별개의 갈래이고 무가드였다(실측: shape_checked_member가
    # raise하지 않게 바꿔도 66예제가 전부 통과). 그 상태에서 실제 동작은
    # 400 INVALID_JSONAPI_DOCUMENT → 422 VALIDATION_ERROR(또는 201)로 바뀌어
    # CrudActions#validate_write_member_shape!와 갈라진다.
    it "rejects a non-object attributes member with 400 INVALID_JSONAPI_DOCUMENT" do
      post "/api/v1/auth/register", params: { data: { type: "users", attributes: "oops" } }.to_json,
                                     headers: jsonapi_headers

      expect_error(status: 400, code: "INVALID_JSONAPI_DOCUMENT")
      expect(parsed_body.dig("errors", 0, "source")).to eq("pointer" => "/data/attributes")
    end

    it "rejects a non-object relationships member with 400 INVALID_JSONAPI_DOCUMENT" do
      body = { data: { type: "users", attributes: { email: email, password: password }, relationships: "oops" } }

      post "/api/v1/auth/register", params: body.to_json, headers: jsonapi_headers

      expect_error(status: 400, code: "INVALID_JSONAPI_DOCUMENT")
      expect(parsed_body.dig("errors", 0, "source")).to eq("pointer" => "/data/relationships")
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

    # 타이밍 오라클 방어의 유일한 가드. "dummy_hash가 호출됐다"만 단언하면
    # 속 빈 가드가 된다 — dummy_hash는 캐시된 상수를 돌려주는 사실상 공짜
    # 호출이라, 그 호출은 남긴 채 verify_password만 건너뛰면 argon2 비용(~30ms)이
    # 존재하는 계정에서만 발생해 응답 시간이 계정 존재를 알려 주는데도 그런
    # 테스트는 통과한다(실측: 그 뮤테이션이 0 failures로 생존했다).
    #
    # 그래서 **어떤 해시가 실제로 verify_password에 들어갔는지**를 단언한다.
    # `and_wrap_original`로 감싸기만 하고 원본을 그대로 호출하므로 검증 대상
    # 구현이 스텁으로 대체되지 않는다. 정본의
    # test_login_uses_dummy_hash_and_hides_email_existence
    # (`assert verified_hashes == [DUMMY_PASSWORD_HASH, user.password_hash]`)와
    # 같은 층위다.
    it "runs argon2 against the dummy hash for an unknown email and against the stored hash for a real one" do
      register!(email: "timing@example.com", password: "correct-horse-battery")
      user = User.find_by!(email: "timing@example.com")
      dummy_hash = Auth::Passwords.dummy_hash
      verified_hashes = []
      allow(Auth::Passwords).to receive(:verify_password).and_wrap_original do |original, candidate, hash|
        verified_hashes << hash
        original.call(candidate, hash)
      end

      login!(email: "nobody-at-all@example.com", password: "whatever-password")
      expect_error(status: 401, code: "INVALID_CREDENTIALS")

      login!(email: "timing@example.com", password: "correct-horse-battery")
      expect(response).to have_http_status(:ok)

      expect(verified_hashes).to eq([ dummy_hash, user.password_hash ])
    end

    # 순서 테스트 2 (스펙 6.5) — 이것이 순서 계약의 진짜 가드다. 활성 여부를
    # 비밀번호보다 먼저 보면 이 테스트만 깨진다(아래 뮤테이션 절에서 실측).
    it "returns 401 INVALID_CREDENTIALS, not 403 USER_INACTIVE, for a wrong password on an inactive account" do
      register!(email: "inactive@example.com", password: "correct-horse-battery")
      User.find_by!(email: "inactive@example.com").update!(is_active: false)

      login!(email: "inactive@example.com", password: "totally-wrong-password")

      expect_error(status: 401, code: "INVALID_CREDENTIALS")
    end

    # 스펙 6.5의 5단계 — 2단계(잠그지 않은 조회)와 4단계(SELECT ... FOR UPDATE)
    # 사이에 행이 삭제된 좁은 경합. 이 가드가 없으면 `nil.is_active?`가 불려
    # NoMethodError → **500**이 난다(무가드였다: 가드를 지워도 39예제가 전부
    # 통과했다).
    #
    # 잠금 **조회**만 nil을 돌려주게 만들고 컨트롤러의 nil 가드 자체는 진짜
    # 구현이 돌게 둔다. 가드를 스텁으로 바꿔치기하면 그 가드를 지워도 통과하는
    # 가짜 가드가 된다 — Task 5의 `email_uniqueness_violation?` 전례가 정확히
    # 그것이었다. 2단계의 `User.find_by(email:)`는 그대로 진짜 행을 돌려주므로
    # 비밀번호 검증(argon2)도 실제로 통과한다.
    it "returns 401 INVALID_CREDENTIALS, not 500, when the row disappears between the password check and the lock" do
      register!(email: "vanished@example.com", password: "correct-horse-battery")
      user = User.find_by!(email: "vanished@example.com")
      locked_scope = instance_double(ActiveRecord::Relation)
      allow(User).to receive(:lock).and_return(locked_scope)
      allow(locked_scope).to receive(:find_by).with(id: user.id).and_return(nil)

      login!(email: "vanished@example.com", password: "correct-horse-battery")

      expect_error(status: 401, code: "INVALID_CREDENTIALS")
    end

    it "returns 403 USER_INACTIVE for the correct password on an inactive account" do
      register!(email: "inactive2@example.com", password: "correct-horse-battery")
      User.find_by!(email: "inactive2@example.com").update!(is_active: false)

      login!(email: "inactive2@example.com", password: "correct-horse-battery")

      expect_error(status: 403, code: "USER_INACTIVE")
    end

    # 저장 직전(register)과 조회 직전(login)이 같은 정규화를 쓰지 않으면 가입한
    # 이메일로 로그인이 안 되는 상태가 생긴다.
    #
    # **로그인 입력도 정규화되지 않은 형태로 보내는 것이 이 테스트의 핵심이다.**
    # 여기에 이미 정규화된 값("mixed.case@example.com")을 보내면 login 쪽
    # normalize_email이 있으나 없으나 결과가 같아져서 register 쪽만 증명하게
    # 된다 — 실측: 그 형태에서는 login의 normalize_email을 지워도 0 failures였다.
    # 실제 영향은 "소문자로 가입한 사용자가 모바일 자동 대문자화된
    # User@Example.com으로 로그인하면 401"이다.
    it "normalizes the email on both sides -- registration and login each accept unnormalized input" do
      register!(email: "  MiXed.Case@EXAMPLE.com  ", password: "correct-horse-battery")
      expect(response).to have_http_status(:created)

      login!(email: " MIXED.case@Example.COM  ", password: "correct-horse-battery")

      expect(response).to have_http_status(:ok)
    end

    # 스펙 6.5의 4단계가 여는 행 잠금(SELECT ... FOR UPDATE)의 가드.
    #
    # 잠금을 지워도(`User.lock.find_by` → `User.find_by`) 위의 모든 테스트가
    # 통과한다 — READ COMMITTED에서는 **이미 커밋된** 비활성화라면 잠금 없는
    # 재조회도 그대로 보기 때문이다. 즉 커밋된 상태만 다루는 테스트로는 두
    # 세계가 원천적으로 구별되지 않는다. 구별되는 것은 **아직 커밋되지 않은**
    # 비활성화가 진행 중인 순간 하나다:
    #
    #   잠금 있음 — 로그인이 그 트랜잭션을 기다렸다가 새 값을 보고 403을 내고
    #               세션을 발급하지 않는다.
    #   잠금 없음 — 기다리지 않고 옛 값(is_active = true)을 보고 200 + 세션 발급.
    #               그 뒤 비활성화가 커밋되면 비활성 계정의 살아 있는 세션이 남는다.
    #
    # 정본 test_login_rechecks_active_state_after_concurrent_deactivation이
    # 지키는 성질과 같다.
    #
    # sleep으로 타이밍을 맞추지 않는다 — pg_stat_activity로 그 요청이 실제로
    # users 행 잠금을 기다렸다는 사실을 관측하고 **관측 자체를 단언한다**.
    # 관측이 실패하면(잠금이 없어서 기다린 적이 없으면) 상태 코드와 무관하게
    # 테스트가 깨진다. 이 저장소의 example_relationship_concurrency_spec.rb와
    # 같은 패턴이다.
    describe "row lock, measured against an uncommitted concurrent deactivation" do
      self.use_transactional_tests = false

      before do
        ActiveRecord::Base.connection_handler.clear_active_connections!
        DatabaseCleaner.clean_with(:truncation)
      end

      after do
        @login_thread&.join(10)
        ActiveRecord::Base.connection_handler.clear_active_connections!
        DatabaseCleaner.clean_with(:truncation)
        ActiveRecord::Base.connection_handler.clear_active_connections!
      end

      def wait_for_user_lock_waiter(pid)
        deadline = Process.clock_gettime(Process::CLOCK_MONOTONIC) + 5
        loop do
          rows = ActiveRecord::Base.connection_pool.with_connection do |connection|
            connection.exec_query(<<~SQL.squish).to_a
              SELECT state, wait_event_type, query FROM pg_stat_activity WHERE pid = #{Integer(pid)}
            SQL
          end
          return true if rows.any? do |row|
            row["wait_event_type"] == "Lock" && row["query"].to_s.match?(/SELECT.+users.+FOR UPDATE/im)
          end
          return false if Process.clock_gettime(Process::CLOCK_MONOTONIC) >= deadline

          sleep 0.02
        end
      end

      it "waits for the deactivating transaction and then refuses to issue a session" do
        email = "lock-race-#{SecureRandom.hex(4)}@example.com"
        register!(email: email, password: "correct-horse-battery")
        user_id = User.find_by!(email: email).id
        backend_pids = Queue.new
        results = Queue.new
        lock_connection = nil

        ActiveRecord::Base.connection_handler.clear_active_connections!
        lock_connection = ActiveRecord::Base.connection_pool.checkout
        lock_connection.begin_db_transaction
        quoted_id = lock_connection.quote(user_id)
        lock_connection.exec_query("SELECT id FROM users WHERE id = #{quoted_id} FOR UPDATE")
        lock_connection.exec_query("UPDATE users SET is_active = false WHERE id = #{quoted_id}")

        @login_thread = Thread.new do
          ActiveRecord::Base.connection_pool.with_connection do |connection|
            session = ActionDispatch::Integration::Session.new(Rails.application)
            backend_pids << connection.raw_connection.backend_pid
            session.post("/api/v1/auth/login",
                         params: login_body(email: email, password: "correct-horse-battery"),
                         headers: jsonapi_headers)
            results << [ session.response.status, session.response.body ]
          end
        end

        waited_for_user_lock = wait_for_user_lock_waiter(backend_pids.pop)
        lock_connection.commit_db_transaction
        ActiveRecord::Base.connection_pool.checkin(lock_connection)
        lock_connection = nil

        status, body = results.pop
        aggregate_failures do
          expect(waited_for_user_lock).to be(true)
          expect(status).to eq(403)
          expect(JSON.parse(body).dig("errors", 0, "code")).to eq("USER_INACTIVE")
          expect(RefreshSession.where(user_id: user_id).count).to eq(0)
        end
      ensure
        if lock_connection
          begin
            lock_connection.rollback_db_transaction
          rescue StandardError
            nil
          end
          ActiveRecord::Base.connection_pool.checkin(lock_connection)
        end
      end
    end

    # register 쪽과 같은 이유(그쪽 코멘트 참고). login에도 같은 갈래가 있고,
    # 정본이 register/login 양쪽에 같은 AuthEmail을 쓰므로 양쪽에 건다.
    it "rejects an email that only exceeds 254 characters after case folding with 422, not 500" do
      raw = "#{'a' * 230}#{'ß' * 11}@example.com"
      expect(raw.strip.downcase(:fold).length).to eq(264)

      login!(email: raw, password: "correct-horse-battery")

      expect_error(status: 422, code: "VALIDATION_ERROR")
      expect(parsed_body.dig("errors", 0, "source")).to eq("pointer" => "/data/attributes/email")
    end

    it "rejects a syntactically invalid email with 422 VALIDATION_ERROR" do
      aggregate_failures do
        [ "not-an-email", "a b@c d", "a", "a@b", ".a@b.com", "a..b@c.com", "a@-b.com", "a@b.1" ].each do |bad|
          login!(email: bad, password: "correct-horse-battery")
          expect_error(status: 422, code: "VALIDATION_ERROR")
          expect(parsed_body.dig("errors", 0, "source")).to eq("pointer" => "/data/attributes/email")
        end
      end
    end

    # register 쪽과 같은 이유(그쪽 코멘트 참고) — 정본이 register/login 양쪽에
    # 같은 AuthEmail을 쓰므로 비ASCII 주소가 **로그인까지** 되어야 한다.
    # 가입만 되고 로그인이 안 되면 계정이 잠기는 것과 같다.
    it "logs in with an internationalized address" do
      register!(email: "shørt@example.com", password: "correct-horse-battery")
      expect(response).to have_http_status(:created)

      login!(email: "SHØRT@Example.com", password: "correct-horse-battery")

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

    # 형태 오류(누락·null·빈 문자열·비문자열)와 "형태는 맞지만 유효하지 않은
    # 토큰"의 경계. 앞쪽은 서명 검증에 **도달하기 전**의 문서 형태 오류라 422이고
    # (정본 `RawRefreshToken = Annotated[str, Field(min_length=1)]` + strict=True를
    # 직접 실행해 실측 — 네 경우 전부 loc이 ("data","attributes","refreshToken")),
    # 뒤쪽은 위의 "garbage input" 테스트가 고정하는 401이다. 둘을 같은 상태
    # 코드로 뭉개면 클라이언트가 "내가 보낸 문서가 틀렸다"와 "토큰이 만료·폐기
    # 됐으니 다시 로그인해야 한다"를 구분하지 못한다.
    it "returns 422 VALIDATION_ERROR when refreshToken is missing, null, empty, or not a string" do
      bodies = [
        { data: { type: "refreshTokens", attributes: { refreshToken: nil } } },
        { data: { type: "refreshTokens", attributes: { refreshToken: "" } } },
        { data: { type: "refreshTokens", attributes: { refreshToken: 123 } } },
        { data: { type: "refreshTokens", attributes: { refreshToken: [ 1, 2 ] } } },
        { data: { type: "refreshTokens", attributes: {} } },
        { data: { type: "refreshTokens" } }
      ]

      aggregate_failures do
        bodies.each do |body|
          post "/api/v1/auth/refresh", params: body.to_json, headers: jsonapi_headers

          expect_error(status: 422, code: "VALIDATION_ERROR")
          expect(parsed_body.dig("errors", 0, "source")).to eq("pointer" => "/data/attributes/refreshToken")
        end
      end
    end

    it "rejects data.type other than refreshTokens with 409 TYPE_MISMATCH" do
      post "/api/v1/auth/refresh", params: refresh_token_body("whatever", type: "authCredentials"),
                                    headers: jsonapi_headers

      expect_error(status: 409, code: "TYPE_MISMATCH")
    end

    # 이 describe 밖의 모든 refresh 테스트는 RSpec의 기본 트랜잭션 픽스처
    # (use_transactional_tests = true) 아래서 돈다 — 매 예제가 이미 RSpec이 열어
    # 둔 트랜잭션 "안"이라 컨트롤러가 여는 `ActiveRecord::Base.transaction`은
    # 바깥 트랜잭션에 **합류**만 한다. 그래서 (a)
    # `ActiveRecord::Base.connection.transaction_open?`이 컨트롤러가 스스로
    # 트랜잭션을 여는지와 무관하게 항상 true이고, (b) 그 블록 안에서 예외가 나도
    # **실제 ROLLBACK이 일어나지 않는다**(refresh_sessions_spec.rb의 "F1" 코멘트가
    # 말하는 것과 같은 함정). 실측: 래핑을 지워도, 그리고 raise를 트랜잭션 안으로
    # 옮겨도 이 describe 밖의 테스트는 전부 그대로 통과했다. 여기서만 픽스처를
    # 끄고 실제 커넥션으로 검증한다.
    describe "runs against a real connection with no ambient RSpec transaction" do
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

      # 컨트롤러 주석이 계약으로 선언한 것 — "Failure는 트랜잭션 블록 안에서
      # 절대 올리지 않고, 블록을 빠져나와 커밋된 뒤에만 올린다" — 의 유일한
      # 가드다. 재사용 감지(`Auth::RefreshSessions.rotate`)는 폐기된 토큰이
      # 재생되면 그 사용자의 **활성 세션 전부**를 끊은 뒤에 Failure를 돌려준다.
      # raise를 트랜잭션 안으로 옮기면 그 일괄 폐기까지 함께 롤백되어, 탈취된
      # 토큰이 재생됐는데도 세션이 하나도 안 끊긴다 — 응답은 똑같은 401이라
      # 상태 코드만 보는 테스트로는 원천적으로 구분되지 않는다. 그래서 DB를
      # 직접 본다.
      it "keeps every session of the user revoked after a rotated token is replayed" do
        email = "replay-#{SecureRandom.hex(4)}@example.com"
        register!(email: email, password: "correct-horse-battery")
        login!(email: email, password: "correct-horse-battery")
        replayed_token = parsed_body.dig("data", "attributes", "refreshToken")
        login!(email: email, password: "correct-horse-battery")
        user_id = User.find_by!(email: email).id

        post "/api/v1/auth/refresh", params: refresh_token_body(replayed_token), headers: jsonapi_headers
        expect(response).to have_http_status(:ok)
        # 회전된 세션은 끊기고 새 세션이 생겼다 — 두 번째 로그인 세션과 함께 2개.
        expect(RefreshSession.where(user_id: user_id, revoked_at: nil).count).to eq(2)

        post "/api/v1/auth/refresh", params: refresh_token_body(replayed_token), headers: jsonapi_headers

        expect_error(status: 401, code: "TOKEN_REVOKED")
        expect(RefreshSession.where(user_id: user_id, revoked_at: nil).count).to eq(0)
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

    # refresh 쪽과 같은 경계(그쪽 코멘트 참고). 정본은 refresh/logout 양쪽에
    # 같은 RefreshTokenDocument를 쓰므로 두 라우트가 같아야 한다.
    it "returns 422 VALIDATION_ERROR when refreshToken is missing, null, empty, or not a string" do
      bodies = [
        { data: { type: "refreshTokens", attributes: { refreshToken: nil } } },
        { data: { type: "refreshTokens", attributes: { refreshToken: "" } } },
        { data: { type: "refreshTokens", attributes: { refreshToken: 123 } } },
        { data: { type: "refreshTokens", attributes: { refreshToken: [ 1, 2 ] } } },
        { data: { type: "refreshTokens", attributes: {} } },
        { data: { type: "refreshTokens" } }
      ]

      aggregate_failures do
        bodies.each do |body|
          post "/api/v1/auth/logout", params: body.to_json, headers: jsonapi_headers

          expect_error(status: 422, code: "VALIDATION_ERROR")
          expect(parsed_body.dig("errors", 0, "source")).to eq("pointer" => "/data/attributes/refreshToken")
        end
      end
    end

    # refresh와 같은 이유(위 "runs against a real connection" 코멘트 참고) — 이
    # describe 밖의 logout 테스트는 RSpec의 기본 트랜잭션 픽스처 아래서 돌아
    # `AuthController#logout`이 스스로 트랜잭션을 여는지도, Failure를 커밋 뒤에
    # 올리는지도 증명하지 못한다.
    describe "runs against a real connection with no ambient RSpec transaction" do
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

      # refresh 쪽 "keeps every session ... replayed"와 같은 계약(Failure는 커밋
      # 뒤에 올린다)의 logout 쪽 가드다. logout에는 재사용 감지가 없으므로
      # (rotate만의 책임) Failure 직전에 상태를 바꾸는 갈래는 **만료** 하나다:
      # `load_verified_session`이 만료된 세션을 폐기한 뒤 Failure(401,
      # TOKEN_EXPIRED)를 돌려준다. raise를 트랜잭션 안으로 옮기면 그 폐기가
      # 롤백되어, 만료된 토큰의 세션이 활성인 채로 DB에 남는다 — 응답은 똑같은
      # 401이다.
      it "keeps the expired session revoked after logout answers 401 TOKEN_EXPIRED" do
        email = "expired-logout-#{SecureRandom.hex(4)}@example.com"
        register!(email: email, password: "correct-horse-battery")
        login!(email: email, password: "correct-horse-battery")
        token = parsed_body.dig("data", "attributes", "refreshToken")
        jti = Auth::Tokens.decode(token, expected_type: "refresh").jti
        RefreshSession.find(jti).update_columns(expires_at: 1.minute.ago)

        post "/api/v1/auth/logout", params: refresh_token_body(token), headers: jsonapi_headers

        expect_error(status: 401, code: "TOKEN_EXPIRED")
        expect(RefreshSession.find(jti).revoked_at).to be_present
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
