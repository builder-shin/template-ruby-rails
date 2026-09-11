# frozen_string_literal: true

# Bearer access token 인증 가드.
#
# app/controllers/concerns/에 있으므로 최상위 상수다(Auth::Tokens 같은 app/lib/
# 아래 것들과 달리 네임스페이스가 없다 — 그 디렉터리가 Zeitwerk 루트다).
#
# 정본 app/auth/dependencies.py의 두 갈래를 그대로 따른다.
#
# - authenticate_user!  == get_current_user   — 유효한 access 토큰이 가리키는
#   사용자가 존재하기만 하면 통과한다. 비활성 사용자도 통과한다.
# - authenticate_active_user! == get_current_active_user — 위에 활성 검사를
#   더한다.
#
# 정본에서 실제로 전수 확인한 결과: `/users/me`는 전자를, 쓰기 라우트
# (ExamplesController#write_dependencies)는 후자를 쓴다. 비활성 사용자도 자기
# 프로필은 읽을 수 있어야 어느 계정이 막혔는지, 누구에게 문의해야 하는지 알 수
# 있다 — 그 확인 자체를 막으면 안 된다.
#
# 이 가드가 실패하는 모든 401은 source.header="Authorization"을 싣는다(정본과
# 동일). 403 USER_INACTIVE는 싣지 않는다 — 정본도 그렇다(사용자를 특정하는 데
# 성공한 뒤의 권한 거부이지, 인증 헤더 자체의 문제가 아니기 때문이다).
module JsonapiAuthentication
  extend ActiveSupport::Concern

  AUTHORIZATION_SOURCE = { header: "Authorization" }.freeze
  private_constant :AUTHORIZATION_SOURCE

  private

  def authenticate_user!
    Current.user = bearer_authenticated_user
  end

  def authenticate_active_user!
    authenticate_user!
    raise JsonApiError.new(status: 403, code: "USER_INACTIVE") unless Current.user.is_active?
  end

  def bearer_authenticated_user
    claims = decode_bearer_access_token(bearer_credential)
    # claims.sub는 서명된 토큰의 문자열 그대로다 — Auth::Tokens.typed_claims는
    # 비어 있지 않은 문자열인지만 보고 UUID 모양까지는 검사하지 않는다(jti와
    # 다르다). NestJS 가드는 그래서 조회 전에 UUID 모양을 직접 거른다(TypeORM이
    # uuid가 아닌 문자열을 그대로 드라이버에 넘겨 PostgreSQL이 22P02로 죽는다).
    # Rails/ActiveRecord는 다르다 — PostgreSQL uuid 컬럼의 OID::Uuid#cast가 정규식에
    # 맞지 않는 문자열을 예외 없이 nil로 캐스팅한다(컨테이너에서 실측:
    # User.find_by(id: "not-a-uuid-string") => nil, 22P02 없음). "sub가 UUID가
    # 아님"과 "sub가 UUID이지만 그런 사용자가 없음"이 여기서는 같은 nil로 저절로
    # 합쳐져 별도 사전 검사가 필요 없다 — 정본이 UUID(claims.sub) 파싱 실패를
    # ValueError로 잡아 INVALID_TOKEN으로 보내는 것과 최종 결과가 같다.
    identifier = Auth::Tokens.uuid_claim(claims.sub)
    raise invalid_token_error unless identifier

    User.find_by(id: identifier) || raise(invalid_token_error)
  end

  # Authorization 헤더에서 Bearer 자격증명을 꺼낸다. 스킴은 대소문자를 가리지
  # 않는다(정본 HTTPBearer의 scheme.lower() != "bearer"와 동일).
  def bearer_credential
    header = request.headers["Authorization"]
    raise authentication_required_error if header.nil?

    scheme, _separator, credential = header.partition(" ")
    raise invalid_token_error if scheme.empty? || credential.empty? || !scheme.casecmp?("bearer")

    credential.strip
  end

  def decode_bearer_access_token(token)
    Auth::Tokens.decode(token, expected_type: "access")
  rescue Auth::Tokens::TokenExpired
    raise JsonApiError.new(status: 401, code: "TOKEN_EXPIRED", source: AUTHORIZATION_SOURCE)
  rescue Auth::Tokens::InvalidToken
    # refresh 토큰이 access 자리에 오는 경우도 여기로 온다 — Auth::Tokens.decode가
    # expected_type: "access"로 type 클레임을 검사해서 InvalidToken을 던진다
    # (Auth::Tokens#typed_claims의 "unexpected token type"). 서명 위조·필수 클레임
    # 누락·aud 불일치도 전부 같은 예외라 여기서 한 번에 INVALID_TOKEN으로 모인다.
    raise invalid_token_error
  end

  def authentication_required_error
    JsonApiError.new(status: 401, code: "AUTHENTICATION_REQUIRED", source: AUTHORIZATION_SOURCE)
  end

  def invalid_token_error
    JsonApiError.new(status: 401, code: "INVALID_TOKEN", source: AUTHORIZATION_SOURCE)
  end
end
