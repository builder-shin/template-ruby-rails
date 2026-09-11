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
    # 이유 — ApiController가 주는 CrudActions가 이 컨트롤러에는 전부 불필요하다)
    # JsonapiNegotiation(406/415/최상위 malformed JSON 400)과
    # JsonapiErrors(예외 → JSON:API 오류 렌더링)는 자동으로 물려받는다.
    class AuthController < ApplicationController
      REGISTER_ATTRIBUTES = %w[email password].freeze
      LOGIN_ATTRIBUTES = %w[email password].freeze
      REFRESH_ATTRIBUTES = %w[refreshToken].freeze
      private_constant :REGISTER_ATTRIBUTES, :LOGIN_ATTRIBUTES, :REFRESH_ATTRIBUTES

      EMAIL_UNIQUE_INDEX = "index_users_on_email"
      private_constant :EMAIL_UNIQUE_INDEX

      def register
        attributes = parse_write_data!(expected_type: "users", allowed_attributes: REGISTER_ATTRIBUTES)
        email = normalized_email!(attributes)
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
        email = normalized_email!(attributes)
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
        raw_token = refresh_token!(attributes)

        outcome = nil
        ActiveRecord::Base.transaction do
          outcome = Auth::RefreshSessions.rotate(raw_token)
        end

        raise JsonApiError.new(status: outcome.status, code: outcome.code) if outcome.is_a?(Auth::RefreshSessions::Failure)

        render_jsonapi_document(AuthTokenSerializer.new(outcome).serializable_hash, status: 200)
      end

      # 로그아웃. logout도 rotate와 같은 Failure 반환 규약을 따른다(위 refresh
      # 코멘트 참고) — 성공(nil)이면 204, 실패면 트랜잭션이 커밋된 뒤에 그
      # Failure를 오류로 바꿔 올린다.
      def logout
        attributes = parse_write_data!(expected_type: "refreshTokens", allowed_attributes: REFRESH_ATTRIBUTES)
        raw_token = refresh_token!(attributes)

        outcome = nil
        ActiveRecord::Base.transaction do
          outcome = Auth::RefreshSessions.logout(raw_token)
        end

        raise JsonApiError.new(status: outcome.status, code: outcome.code) if outcome

        head :no_content
      end

      private

      # Auth documents are strict schema envelopes. Collect independent member
      # and value errors before touching persistence, with escaped JSON pointers.
      def parse_write_data!(expected_type:, allowed_attributes:)
        document = JSON.parse(jsonapi_body)
        raise JsonApiError.new(status: 422, code: "VALIDATION_ERROR") unless document.is_a?(Hash)
        errors = []
        (document.keys - [ "data" ]).each { |key| errors << auth_pointer(key) }
        data = document["data"]
        unless data.is_a?(Hash) || data.is_a?(ActionController::Parameters)
          errors << "/data"
          raise_auth_errors!(errors)
        end
        (data.keys - %w[type attributes]).each { |key| errors << "/data/#{auth_pointer(key).delete_prefix('/')}" }
        errors << "/data/type" unless data["type"] == expected_type
        attributes = data["attributes"]
        if attributes.is_a?(Hash) || attributes.is_a?(ActionController::Parameters)
          (attributes.keys - allowed_attributes).each { |key| errors << "/data/attributes#{auth_pointer(key)}" }
          allowed_attributes.each do |name|
            value = attributes[name]
            valid = if name == "email"
              begin
                Auth::EmailIdentity.normalize(value)
                true
              rescue ArgumentError
                false
              end
            elsif name == "password"
              value.is_a?(String) && value.length.between?(12, 128)
            else
              value.is_a?(String) && !value.empty?
            end
            errors << "/data/attributes/#{name}" unless valid
          end
        else
          errors << "/data/attributes"
        end
        raise_auth_errors!(errors) unless errors.empty?
        attributes
      end

      def auth_pointer(key)
        "/" + key.to_s.gsub("~", "~0").gsub("/", "~1")
      end

      def raise_auth_errors!(pointers)
        raise JsonApiError.new(status: 422, code: "VALIDATION_ERROR", sources: pointers.map { |pointer| { pointer: pointer } })
      end

      def bounded_string!(attributes, name, min:, max:)
        value = attributes[name]
        return value if value.is_a?(String) && value.length.between?(min, max)

        invalid_attribute!(name)
      end

      def invalid_attribute!(name)
        raise JsonApiError.new(status: 422, code: "VALIDATION_ERROR", source: { pointer: "/data/attributes/#{name}" })
      end

      # The same helper drives registration, lookup and migration preflight.
      def normalized_email!(attributes)
        Auth::EmailIdentity.normalize(attributes["email"])
      rescue ArgumentError
        invalid_attribute!("email")
      end

      # refreshToken은 "비어 있지 않은 문자열"이어야 한다 — 정본
      # `RawRefreshToken = Annotated[str, Field(min_length=1)]` + JsonApiWriteSchema의
      # `strict=True`(app/jsonapi/naming.py)와 같은 계약이다. 누락·null·빈 문자열·
      # 비문자열은 서명 검증에 도달하기 전의 **문서 형태 오류**이므로 401이 아니라
      # 422 VALIDATION_ERROR다(정본에서 실측: 네 경우 전부 loc이
      # ("data","attributes","refreshToken")인 RequestValidationError). 형태는
      # 맞는데 유효하지 않은 토큰은 그대로 401이다 — 그 경계를 흐리지 않는다.
      # 상한은 두지 않는다(정본에 min_length만 있고 max_length가 없다).
      #
      # Auth::Tokens.decode_payload의 `token.is_a?(String)` 가드는 그대로 둔다 —
      # 이 컨트롤러 말고도 그 모듈을 부르는 자리가 있을 수 있는 심층 방어다.
      def refresh_token!(attributes)
        value = attributes["refreshToken"]
        invalid_attribute!("refreshToken") unless value.is_a?(String) && !value.empty?

        value
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
      #
      # `payload.as_json`을 거치는 이유는 CrudActions#render_jsonapi_payload의
      # 코멘트와 같다 — `JSON.generate`만으로는 Time이 `to_s`를 타서 ISO-8601이
      # 아닌 문자열이 나가고, 그러면 register의 201이 내는 createdAt과
      # GET /api/v1/users/me가 내는 같은 필드의 형식이 갈린다. 두 곳을 같이
      # 고쳐야 한다 — 한쪽만 고치면 갈림이 그대로 남는다.
      def render_jsonapi_document(payload, status:, location: nil)
        response.status = status
        response.headers["Content-Type"] = JSONAPI::MEDIA_TYPE
        response.headers["Location"] = location if location
        self.response_body = JSON.generate(payload.as_json)
      end
    end
  end
end
