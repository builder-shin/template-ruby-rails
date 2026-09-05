# frozen_string_literal: true

require "securerandom"

module Auth
  # refresh 세션의 발급 · 회전 · 재사용 감지 · 로그아웃.
  #
  # **트랜잭션은 호출자가 소유한다.** 이 모듈은 어디서도 `ActiveRecord::Base.transaction`을
  # 열지 않는다 — `rotate`/`logout`이 잠그는 `users`·`refresh_sessions` 행은 호출자(향후
  # Task 4/5의 컨트롤러)가 이미 열어 둔 트랜잭션 안에서 잠겨야 한다. 정본(FastAPI)이
  # `session.begin()`을 컨트롤러 쪽에 두는 것과 같은 이유다.
  #
  # **실패는 예외가 아니라 `Failure` 반환값으로 표현한다.** `rotate`/`logout`은 실패
  # 갈래에서도 이미 DB 행을 바꾼 뒤(재사용 감지의 일괄 폐기, 만료 세션의 폐기 등)
  # 그 결과를 반환할 때가 있다 — 이 변경은 "예정된" 것이 아니라 "이미 실행된" 보안
  # 상태 변경이다. 여기서 예외를 던지면 호출자의 `ActiveRecord::Base.transaction`
  # 블록이 그 예외로 롤백되면서, 방금 실행된 폐기까지 통째로 사라진다 — 재사용을
  # 감지해 세션을 전부 끊어놓고, 그 감지 자체가 없었던 일이 되어버리는 것이다.
  # `Failure`를 평범한 반환값으로 돌려주면 호출자는 트랜잭션을 정상적으로 커밋하면서
  # (그 안에 담긴 폐기를 함께 커밋하면서) 에러 응답을 렌더링할 수 있다. 정본의
  # `RefreshSessionError`가 예외가 아니라 반환형인 이유, 그 docstring이 "staged
  # security state changes"라고 적은 이유가 이것이다. 이 모듈이 raise를 쓰는 곳은
  # 전부 "호출자의 실수"(예: 영속화되지 않은 User를 넘김)뿐이고, "토큰이 이상하다"는
  # 전부 반환값이다.
  module RefreshSessions
    # 회전·최초 발급이 만들어내는 access/refresh 토큰 쌍.
    TokenPair = Struct.new(
      :id, :access_token, :refresh_token, :token_type, :expires_in, :refresh_expires_in,
      keyword_init: true
    )

    # 이미 실행됐을 수도 있는 보안 상태 변경을 실은 안전한 실패 결과. 위 모듈
    # 코멘트 참고 — 예외로 올리지 않는 것이 이 타입이 존재하는 이유다.
    Failure = Struct.new(:status, :code, keyword_init: true)

    module_function

    # 호출자가 이미 `SELECT ... FOR UPDATE`로 잠근 사용자에게 새 토큰 쌍을 발급한다.
    # 여기서는 잠그지 않고 `user.is_active?`도 보지 않는다 — 둘 다 호출자의 책임이다
    # (정본의 `issue_token_pair_for_locked_user`와 동일한 계약). `rotate`가 내부에서
    # 이 메서드를 부를 때는 이미 사용자를 잠그고 활성 여부까지 확인한 뒤이므로 다시
    # 검사하지 않는다 — 최초 로그인(Task 4/5)에서 이 메서드를 직접 부를 때도 마찬가지로,
    # 잠금과 활성 검사는 호출자가 끝내 두어야 한다.
    def issue_for_locked_user(user)
      # JWT의 iat/exp는 정수 초 단위라 소수점 이하가 잘린다. refresh_sessions.expires_at은
      # datetime 컬럼이라 자르지 않으면 마이크로초가 남는다 — 발급 시각을 여기서 한 번만
      # 초 단위로 잘라 두 계산에 그대로 재사용해야 세션의 expires_at이 refresh 토큰의
      # exp 클레임과 정확히 같은 시각을 가리킨다(정본의 `.replace(microsecond=0)`와
      # 같은 이유 — Auth::Tokens.create도 내부에서 `now.to_i`로 다시 자르지만, 이 메서드가
      # 별도로 계산하는 expires_at:은 그 잘림을 거치지 않으므로 여기서 먼저 잘라야 둘이
      # 어긋나지 않는다).
      issued_at = Time.at(Time.now.to_i).utc
      refresh_jti = SecureRandom.uuid

      access_token = Auth::Tokens.create(user.id, type: "access", now: issued_at)
      refresh_token = Auth::Tokens.create(user.id, type: "refresh", jti: refresh_jti, now: issued_at)

      RefreshSession.create!(
        id: refresh_jti,
        user_id: user.id,
        token_hash: Auth::Tokens.hash_refresh_token(refresh_token),
        expires_at: issued_at + Auth::Tokens.config.refresh_expires_seconds
      )

      TokenPair.new(
        id: refresh_jti,
        access_token: access_token,
        refresh_token: refresh_token,
        token_type: "Bearer",
        expires_in: Auth::Tokens.config.access_expires_seconds,
        refresh_expires_in: Auth::Tokens.config.refresh_expires_seconds
      ).freeze
    end

    # 하나의 refresh token을 회전하거나, 회전 대신 필요한 폐기를 실행하고 그 결과를
    # 반환한다. 아래 세 갈래는 전부 `load_verified_session`이 사용자→세션 순서로
    # 잠근 뒤의 이야기다.
    def rotate(raw_token)
      verified = load_verified_session(raw_token)
      return verified if verified.is_a?(Failure)

      user, session, now = verified

      # 이미 폐기된 세션으로 다시 회전을 시도했다 — 이 refresh token은 이미 한 번
      # 쓰였다는 뜻이다. 정상적인 클라이언트는 자신이 폐기한 토큰을 다시 보내지
      # 않으므로, 이것은 토큰이 탈취되어 원 소유자와 공격자가 같은 토큰을 각자
      # 회전시키려 한 상황과 구분할 수 없다. 이 세션 하나만 마저 폐기해서는
      # 부족하다 — 공격자가 먼저 회전에 성공해 이미 새 세션을 만들어 뒀을 수
      # 있기 때문이다. 그래서 이 세션 하나가 아니라 **그 사용자의 활성 세션
      # 전부**를 끊는다. 다른 사용자의 세션은 아래 WHERE의 user_id 조건에 걸리지
      # 않으므로 손대지 않는다.
      if session.revoked_at.present?
        RefreshSession.where(user_id: session.user_id, revoked_at: nil).update_all(revoked_at: now)
        return failure(401, "TOKEN_REVOKED")
      end

      unless user.is_active?
        session.update!(revoked_at: now)
        return failure(403, "USER_INACTIVE")
      end

      session.update!(revoked_at: now)
      token_pair = issue_for_locked_user(user)
      # 정본은 여기서 `session.flush()`로 새 행을 먼저 DB에 내보낸 뒤 replaced_by_id를
      # 대입한다 — SQLAlchemy의 unit-of-work가 INSERT/UPDATE 실행을 커밋(또는 명시적
      # flush)까지 지연시키므로, 별도로 flush하지 않으면 새 행이 실제로 쓰이기 전에
      # 그 id를 참조하는 UPDATE가 먼저 나갈 수 있어서다. ActiveRecord는 다르다 —
      # `issue_for_locked_user` 안의 `create!`가 그 호출 안에서 즉시 INSERT를 실행하므로
      # (지연이 없다) 이 메서드가 반환한 시점에 새 행은 이미 DB에 존재한다. 그래서
      # Rails 쪽에는 flush에 대응하는 단계가 없다.
      session.update!(replaced_by_id: token_pair.id)
      token_pair
    end

    # 하나의 refresh 세션을 폐기한다. 멱등하다 — 이미 폐기된 세션을 다시 로그아웃해도
    # revoked_at은 처음 값 그대로 남는다. `load_verified_session`은 이미 폐기된
    # 세션도(아직 만료되지 않았다면) 정상적으로 돌려준다는 점이 이 멱등성의 전제다:
    # 두 번째 로그아웃 호출도 여기까지 도달하고, `revoked_at || now`가 처음 값을
    # 지켜준다. rotate와 달리 logout은 revoked_at이 이미 있어도 그 사용자의 다른
    # 세션을 건드리지 않는다 — 재사용 감지는 rotate만의 책임이다.
    def logout(raw_token)
      verified = load_verified_session(raw_token)
      return verified if verified.is_a?(Failure)

      _user, session, now = verified
      session.update!(revoked_at: session.revoked_at || now)
      nil
    end

    # raw refresh token을 해석해 사용자→세션 순서로 잠그고, 만료를 확인한다.
    # `rotate`/`logout`이 공유하는 전처리이며, 모듈 코멘트대로 트랜잭션을 스스로
    # 열지 않는다 — 호출자의 트랜잭션 안에서 잠근다.
    #
    # **잠금 순서: 사용자 먼저, 세션 나중.** 이 모듈의 두 진입점(rotate·logout)이
    # 전부 이 순서 하나로만 잠그므로 이 모듈만 놓고 보면 스스로와는 교착하지 않는다
    # — 하지만 앞으로 다른 코드가 세션을 먼저 잠그고 사용자를 나중에 잠그는 경로를
    # 추가하면, 두 요청이 반대 순서로 서로를 기다리며 교착할 수 있다. 이 순서를
    # 바꾸지 마라.
    def load_verified_session(raw_token)
      claims, token_was_expired = decode_refresh_claims(raw_token)
      return claims if claims.is_a?(Failure)

      user = lock_claimed_user(claims)
      return failure(401, "INVALID_TOKEN") if user.nil?

      session = RefreshSession.lock.find_by(id: claims.jti)
      return failure(401, "INVALID_TOKEN") unless session && session_matches_claims?(session, claims, raw_token)

      now = Time.current
      if token_was_expired || session.expires_at <= now
        # 세션이 이미 폐기돼 있었다면 그 시각을 그대로 지킨다 — logout과 같은
        # 멱등성 규칙. 여기 도달하는 두 번째 호출(예: 이미 만료 처리된 토큰으로
        # rotate를 다시 시도)에서 revoked_at 타임스탬프가 호출마다 밀리지 않게 한다.
        session.update!(revoked_at: session.revoked_at || now)
        return failure(401, "TOKEN_EXPIRED")
      end

      [ user, session, now ]
    end

    # claims를 해석한다. 서명은 유효하지만 만료된 토큰은 `decode_expired_refresh`로
    # 다시 읽어(만료만 눈감아 준다) 세션을 회수할 수 있게 하고, 그 경우
    # `token_was_expired`를 true로 표시해 둔다 — rotate/logout이 "만료됐지만 세션은
    # 찾아 폐기할 수 있다"와 "서명 자체를 신뢰할 수 없다"를 구분해야 하기 때문이다.
    # 서명이 깨진 토큰은 jti를 신뢰할 수 없으므로 어떤 세션도 건드리지 않는다.
    def decode_refresh_claims(raw_token)
      claims = Auth::Tokens.decode(raw_token, expected_type: "refresh")
      [ claims, false ]
    rescue Auth::Tokens::TokenExpired
      begin
        [ Auth::Tokens.decode_expired_refresh(raw_token), true ]
      rescue Auth::Tokens::InvalidToken
        [ failure(401, "INVALID_TOKEN"), false ]
      end
    rescue Auth::Tokens::InvalidToken
      [ failure(401, "INVALID_TOKEN"), false ]
    end

    # claims.sub가 가리키는 사용자를 잠근 채 읽는다. `User.lock.find_by(id:)`에 UUID
    # 모양이 아닌 문자열을 넘겨도(컨테이너에서 직접 실측) PostgreSQL 어댑터가 캐스트
    # 실패를 조용히 nil로 바꿔 반환한다 — 22P02로 죽지 않는다. 정본은 `UUID(claims.sub)`를
    # 직접 파싱해 같은 경우를 애플리케이션 레벨에서 걸러내지만(ValueError면 None), Rails는
    # 어댑터가 이미 그 안전장치를 갖고 있어 별도 가드가 필요 없다 —
    # refresh_sessions_spec.rb의 "sub가 UUID 모양이 아니다" 케이스가 이 의존을 고정한다.
    def lock_claimed_user(claims)
      User.lock.find_by(id: claims.sub)
    end

    # 세션이 이 claims·raw_token과 실제로 짝인지 확인한다. user_id 비교에 별도
    # 대소문자 정규화가 없는 이유: `session.user_id`는 Postgres uuid 컬럼이 돌려주는
    # 소문자 정규형이고, `claims.sub`는 항상 `user.id.to_s`에서 나와(발급 시점,
    # `issue_for_locked_user`) 이미 같은 소문자 정규형이다 — 양쪽 다 이 메서드가 다시
    # 낮출 필요가 없다(claims.jti를 Auth::Tokens가 낮추는 것과는 다르다 — jti는 토큰
    # 발급자가 임의 대소문자로 써 넣을 수 있는 입력이지만, sub는 이 코드베이스 자체가
    # 항상 소문자로만 만들어 낸다).
    #
    # `Auth::Tokens.refresh_token_matches?`는 두 인자 중 하나가 nil이면 죽는다(stored_hash가
    # nil이면 NoMethodError, token이 nil이면 TypeError) — 여기서는 둘 다 nil일 수 없다:
    # raw_token은 이 메서드에 도달하기 전에 이미 `Auth::Tokens.decode`(또는
    # decode_expired_refresh)를 통과한 진짜 문자열이고, session.token_hash는
    # `refresh_sessions.token_hash`가 `NOT NULL` + presence 검증이라 영속화된 행이면
    # 항상 값을 갖는다. 그래서 별도 nil 가드를 두지 않는다.
    def session_matches_claims?(session, claims, raw_token)
      session.user_id == claims.sub && Auth::Tokens.refresh_token_matches?(raw_token, session.token_hash)
    end

    def failure(status, code)
      Failure.new(status: status, code: code).freeze
    end

    private_class_method :load_verified_session, :decode_refresh_claims, :lock_claimed_user,
                          :session_matches_claims?, :failure
  end
end
