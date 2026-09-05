# frozen_string_literal: true

module Api
  module V1
    # 가입 · 로그인 · refresh 회전 · 로그아웃.
    #
    # CrudActions를 쓰지 않는다(스펙 6.8) — 자원 하나의 CRUD가 아니라 서로 다른 네
    # 동작이고, 요청·응답 자원 타입도 액션마다 다르다(users → users,
    # authCredentials → authTokens, refreshTokens → authTokens, refreshTokens →
    # 본문 없음). CrudActions를 그대로 include하지 않은 더 구체적인 이유:
    # 그 concern은 `klass`(= controller_name.classify.constantize)라는 단일 모델을
    # 전제로 설계돼 있다 — 이 컨트롤러의 controller_name "auth"는 어떤
    # ActiveRecord 모델도 classify되지 않고(app/lib/auth의 `Auth` 모듈로
    # constantize는 되지만 `.column_names`가 없어 첫 쓰기 검증에서 바로
    # NoMethodError가 난다), 애초에 액션마다 자원 타입이 갈리는 이 컨트롤러에는
    # "컨트롤러당 자원 하나"라는 전제 자체가 맞지 않는다.
    #
    # 대신 문서 파싱·오류 조립은 CrudActions#validate_jsonapi_write_document!와
    # 같은 코드·같은 pointer 규칙을 내도록 아래 private 메서드들로 다시 구현한다
    # — 그래야 오류 모양이 CRUD 라우트와 어긋나지 않는다(TYPE_MISMATCH·
    # INVALID_JSONAPI_DOCUMENT의 상태 코드와 pointer 조립 방식이 CrudActions와
    # 동일). ApplicationController를 직접 물려받으므로(UsersController와 같은
    # 이유 — ApiController가 주는 CrudActions·레거시 set_current_user 흐름이
    # 전부 불필요하다) JsonapiNegotiation(406/415/최상위 malformed JSON 400)과
    # JsonapiErrors(예외 → JSON:API 오류 렌더링)는 자동으로 물려받는다.
    class AuthController < ApplicationController
      REGISTER_ATTRIBUTES = %w[email password].freeze
      LOGIN_ATTRIBUTES = %w[email password].freeze
      REFRESH_ATTRIBUTES = %w[refreshToken].freeze
      private_constant :REGISTER_ATTRIBUTES, :LOGIN_ATTRIBUTES, :REFRESH_ATTRIBUTES

      # users.email의 유니크 위반이 PG 진단 필드에 싣는 제약 이름. 컨테이너에서
      # 실측(PG::Result#error_field(PG::Result::PG_DIAG_CONSTRAINT_NAME)):
      # db/migrate/20260205000000_create_auth_schema.rb의 `t.index :email,
      # unique: true`는 이름을 지정하지 않아 Rails 기본 명명 규칙으로
      # "index_users_on_email"이 되고, Postgres는 UNIQUE 제약을 지원 유니크
      # 인덱스로 구현하므로 위반 시 진단 필드에 실리는 이름도 이 인덱스명과
      # 같다. 다른 유니크 위반(예: 앞으로 users에 추가될 다른 유니크 컬럼)의
      # 제약 이름은 이와 다르므로 register가 "이메일 중복"으로 잘못 보고하지
      # 않는다.
      EMAIL_UNIQUE_INDEX = "index_users_on_email"
      private_constant :EMAIL_UNIQUE_INDEX

      # 가입. 스펙 6.7 — 중복은 사전 조회로 막지 않는다. User#email에는
      # uniqueness 검증이 없다(app/models/user.rb 참고) — DB 유니크 인덱스가
      # INSERT 시점에 막게 두고, 그 위반(ActiveRecord::RecordNotUnique)만 여기서
      # 붙잡아 409 EMAIL_ALREADY_REGISTERED로 옮긴다. 제약 이름을 확인해 이메일
      # 유니크 위반일 때만 바꾸고, 그 외의 유니크 위반은 그대로 다시 던져
      # 상위(JsonapiErrors)의 기본 RESOURCE_CONFLICT 처리로 넘긴다.
      def register
        attributes = parse_write_data!(expected_type: "users", allowed_attributes: REGISTER_ATTRIBUTES)
        email = normalize_email(bounded_string!(attributes, "email", min: 1, max: 254))
        password = bounded_string!(attributes, "password", min: 12, max: 128)

        payload = nil
        begin
          ActiveRecord::Base.transaction do
            user = User.create!(email: email, password_hash: Auth::Passwords.hash_password(password))
            payload = UserSerializer.new(user).serializable_hash
          end
        rescue ActiveRecord::RecordNotUnique => e
          raise JsonApiError.new(status: 409, code: "EMAIL_ALREADY_REGISTERED") if email_uniqueness_violation?(e)

          raise
        end

        render_jsonapi_document(payload, status: 201, location: "/api/v1/users/me")
      end

      # 로그인. 스펙 6.5의 순서 계약 — 반드시 이 순서를 지킨다:
      #
      #   1. 이메일로 (잠그지 않고) 조회한다.
      #   2. 사용자가 있든 없든 argon2 검증을 한 번 반드시 돌린다 — 없으면
      #      Auth::Passwords.dummy_hash를 대신 검증한다. 여기서 조기 반환하면
      #      응답 시간이 "그 계정은 없다"를 알려준다(계정 열거).
      #   3. 사용자가 없거나 비밀번호가 틀리면 401 INVALID_CREDENTIALS. 활성
      #      여부는 아직 보지 않는다 — 비밀번호를 모르는 사람이 403
      #      USER_INACTIVE와의 차이로 계정 존재를 알아내면 안 된다.
      #   4. 여기서부터 비밀번호가 확인된 사용자만 남는다. 이제 사용자 행을
      #      잠근다(SELECT ... FOR UPDATE) — Task 3은 이 잠금을 대신해 줄 공개
      #      메서드(정본의 lock_user_for_refresh)를 일부러 만들지 않았다
      #      (Auth::RefreshSessions.lock_claimed_user는 private_class_method다).
      #      그래서 로그인이 직접 잠근다. 비밀번호 검증(2번)은 이 잠금 밖에서
      #      끝나 있다 — argon2 검증(~30ms)을 행 잠금을 쥔 채로 돌리면 같은
      #      사용자의 동시 로그인·refresh 요청이 그동안 줄줄이 대기한다.
      #   5. 잠근 뒤 그 행이 사라졌으면(2·4단계 사이에 삭제) 401
      #      INVALID_CREDENTIALS로 취급한다.
      #   6. 이제야 활성 여부를 본다 — 403 USER_INACTIVE.
      #   7. Auth::RefreshSessions.issue_for_locked_user에 발급을 맡긴다 — 이미
      #      잠그고 활성까지 확인한 뒤이므로 그 계약과 정확히 맞는다.
      def login
        attributes = parse_write_data!(expected_type: "authCredentials", allowed_attributes: LOGIN_ATTRIBUTES)
        email = normalize_email(bounded_string!(attributes, "email", min: 1, max: 254))
        password = bounded_string!(attributes, "password", min: 12, max: 128)

        payload = nil
        ActiveRecord::Base.transaction do
          user = User.find_by(email: email)
          password_hash = user&.password_hash || Auth::Passwords.dummy_hash
          password_matches = Auth::Passwords.verify_password(password, password_hash)
          raise JsonApiError.new(status: 401, code: "INVALID_CREDENTIALS") if user.nil? || !password_matches

          locked_user = User.lock.find_by(id: user.id)
          raise JsonApiError.new(status: 401, code: "INVALID_CREDENTIALS") if locked_user.nil?
          raise JsonApiError.new(status: 403, code: "USER_INACTIVE") unless locked_user.is_active?

          token_pair = Auth::RefreshSessions.issue_for_locked_user(locked_user)
          payload = AuthTokenSerializer.new(token_pair).serializable_hash
        end

        render_jsonapi_document(payload, status: 200)
      end

      # Refresh 회전. Auth::RefreshSessions.rotate는 실패도 예외가 아니라 반환값
      # (Failure)으로 알린다 — 재사용 감지의 일괄 폐기처럼 이미 실행된 보안 상태
      # 변경이 실려 있을 수 있어서다. 여기서 그걸 예외로 바꿔 올리면 이 트랜잭션
      # 블록이 롤백되며 방금 실행된 폐기까지 되돌아간다 — 그래서 트랜잭션 블록
      # "안"에서는 절대 올리지 않고, 블록을 빠져나와 커밋된 뒤에만 Failure를
      # JsonApiError로 바꿔 올린다.
      def refresh
        attributes = parse_write_data!(expected_type: "refreshTokens", allowed_attributes: REFRESH_ATTRIBUTES)

        outcome = nil
        ActiveRecord::Base.transaction do
          outcome = Auth::RefreshSessions.rotate(attributes["refreshToken"])
        end

        raise JsonApiError.new(status: outcome.status, code: outcome.code) if outcome.is_a?(Auth::RefreshSessions::Failure)

        render_jsonapi_document(AuthTokenSerializer.new(outcome).serializable_hash, status: 200)
      end

      # 로그아웃. logout도 rotate와 같은 Failure 반환 규약을 따른다(위 refresh
      # 코멘트 참고) — 성공(nil)이면 204, 실패면 트랜잭션이 커밋된 뒤에 그
      # Failure를 오류로 바꿔 올린다.
      def logout
        attributes = parse_write_data!(expected_type: "refreshTokens", allowed_attributes: REFRESH_ATTRIBUTES)

        outcome = nil
        ActiveRecord::Base.transaction do
          outcome = Auth::RefreshSessions.logout(attributes["refreshToken"])
        end

        raise JsonApiError.new(status: outcome.status, code: outcome.code) if outcome

        head :no_content
      end

      private

      # data.type 검증, attributes/relationships의 멤버 모양 검증, 허용되지 않는
      # attribute 거부, relationships 전면 거부까지 CrudActions#validate_jsonapi_write_document!와
      # 같은 순서·같은 오류 코드·같은 pointer 조립으로 수행한다. 검증을 통과한
      # attributes(ActionController::Parameters, 원시 문자열 값)를 돌려준다 —
      # email/password 같은 값 자체의 검증(길이 등)은 각 액션이 이어서 한다.
      #
      # refreshToken은 여기서 String인지·비어 있지 않은지 검사하지 않는다.
      # `{"refreshToken": 123}`처럼 문자열이 아닌 값도, nil도 그대로
      # Auth::RefreshSessions.rotate/logout에 넘어간다 — Auth::Tokens.decode_payload가
      # `token.is_a?(String)`이 아니면 InvalidToken을 던지고, 그 모듈이 이미 그걸
      # Failure(401, "INVALID_TOKEN")으로 바꿔 반환하므로(refresh_sessions_spec.rb의
      # "rejects nil and an empty string without raising" 참고) 여기서 또 검사하면
      # 같은 판정을 두 곳에서 하게 된다.
      def parse_write_data!(expected_type:, allowed_attributes:)
        data = params[:data]
        raise JsonApiError.new(status: 400, code: "INVALID_JSONAPI_DOCUMENT") unless data.is_a?(ActionController::Parameters)

        require_type!(data, expected_type)

        attributes = shape_checked_member(data, :attributes)
        relationships = shape_checked_member(data, :relationships)

        reject_unsupported_attributes!(attributes, allowed_attributes)
        reject_relationships!(relationships)

        attributes
      end

      def require_type!(data, expected_type)
        return if data[:type] == expected_type

        raise JsonApiError.new(status: 409, code: "TYPE_MISMATCH", source: { pointer: "/data/type" })
      end

      # data.attributes/data.relationships가 있다면 반드시 객체(ActionController::Parameters)
      # 여야 한다는 모양 검증. 멤버 자체가 없으면(예: relationships를 아예 안 보낸
      # 요청) 빈 Parameters를 돌려준다 — CrudActions#validate_write_member_shape!가
      # "member가 없으면 통과, 있는데 모양이 틀리면 400"인 것과 같다.
      def shape_checked_member(data, member)
        return ActionController::Parameters.new unless data.key?(member)

        value = data[member]
        return value if value.is_a?(ActionController::Parameters)

        raise JsonApiError.new(status: 400, code: "INVALID_JSONAPI_DOCUMENT", source: { pointer: "/data/#{member}" })
      end

      def reject_unsupported_attributes!(attributes, allowed)
        unsupported = attributes.keys.find { |key| allowed.exclude?(key) }
        return unless unsupported

        raise JsonApiError.new(
          status: 400,
          code: "INVALID_JSONAPI_DOCUMENT",
          source: { pointer: "/data/attributes/#{unsupported}" }
        )
      end

      # 이 네 라우트는 관계를 하나도 갖지 않는다 — users·authCredentials·
      # refreshTokens 어느 자원도 관계 스키마가 없다. CrudActions가 만드는
      # 라우트가 스키마에 없는 관계 이름을 400 INVALID_JSONAPI_DOCUMENT로
      # 거절하는 것(validate_allowed_relationships!, allowed_relationships가
      # 빈 자원 기준)과 같은 모양으로 맞춘다 — 안 그러면 같은 실수(스키마에
      # 없는 관계를 보냄)가 자원마다 다르게 취급된다.
      def reject_relationships!(relationships)
        name = relationships.keys.first
        return if name.nil?

        raise JsonApiError.new(
          status: 400,
          code: "INVALID_JSONAPI_DOCUMENT",
          source: { pointer: "/data/relationships/#{name}" }
        )
      end

      # email·password 둘 다 값 자체의 검증은 여기 하나로 모은다(길이 위반 →
      # 422 VALIDATION_ERROR, pointer는 CrudActions의 RecordInvalid 변환과 같은
      # 자리 규칙). 컨테이너에서 실측: 기존 쓰기 라우트(POST /examples)에 200자
      # 제한을 넘는 title을 보내면 정확히 이 코드(422 VALIDATION_ERROR, pointer
      # /data/attributes/title)가 나온다 — 그 값을 그대로 고정한다.
      #
      # 존재 자체를 검증하지 않고 downstream에 맡길 수 없는 이유(refreshToken과
      # 다른 점): email은 정규화(strip)에서, password는 Auth::Passwords.verify_password에서
      # nil이 오면 예외 없이 그대로 죽는다(각각 NoMethodError/TypeError) — 이
      # 컨트롤러가 직접 막아야 500을 피한다.
      def bounded_string!(attributes, name, min:, max:)
        value = attributes[name]
        return value if value.is_a?(String) && value.length.between?(min, max)

        raise JsonApiError.new(status: 422, code: "VALIDATION_ERROR", source: { pointer: "/data/attributes/#{name}" })
      end

      # 저장 직전(register)과 조회 직전(login) 둘 다 이 메서드 하나만 거친다 —
      # 두 경로가 각자 정규화를 다시 구현하면 그 사이가 갈릴 때 가입한 이메일로
      # 로그인이 안 되는 상태가 조용히 생긴다. 정본의 `email.strip().casefold()`와
      # 맞춘다: Ruby String에는 casefold가 없어 `String#downcase(:fold)`(전체
      # 유니코드 케이스 폴딩)를 쓴다 — 단순 downcase보다 casefold에 더 가깝다.
      def normalize_email(email)
        email.strip.downcase(:fold)
      end

      def email_uniqueness_violation?(error)
        cause = error.cause
        return false unless cause.respond_to?(:result) && cause.result

        cause.result.error_field(PG::Result::PG_DIAG_CONSTRAINT_NAME) == EMAIL_UNIQUE_INDEX
      end

      # CrudActions#render_jsonapi_payload와 같은 방식으로 응답을 조립한다(Content-Type을
      # 문자열로 직접 대입 — charset 없음, render jsonapi:가 아니다). 이 컨트롤러의
      # 네 액션 전부가 "쓰기" 응답이라 CrudActions의 write 경로(create/update 등)와
      # 모양을 맞추는 쪽을 택했다 — UsersController#me(render jsonapi:, GET)와는
      # 다르다.
      def render_jsonapi_document(payload, status:, location: nil)
        response.status = status
        response.headers["Content-Type"] = JSONAPI::MEDIA_TYPE
        response.headers["Location"] = location if location
        self.response_body = JSON.generate(payload)
      end
    end
  end
end
