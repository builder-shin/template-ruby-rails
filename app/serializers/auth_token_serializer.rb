# frozen_string_literal: true

# 로그인·refresh 회전이 발급하는 access/refresh 토큰 쌍(Auth::RefreshSessions::TokenPair).
# 정본 AuthTokenSerializer(resource_path=None)와 동일하게 self 링크가 없다 — 이
# 자원은 발급된 그 응답에만 존재하고 URL로 다시 조회할 방법이 없다. 다른
# 시리얼라이저들과 달리 `link :self`를 아예 선언하지 않는다: jsonapi-serializer는
# 링크가 하나도 등록되지 않은 자원에는 `links` 멤버 자체를 문서에 넣지 않는다
# (빈 `links: {}`를 내는 게 아니다) — spec/requests/api/v1/auth_spec.rb가 이
# 부재를 고정한다.
class AuthTokenSerializer < ApplicationSerializer
  set_key_transform :camel_lower
  set_type :auth_tokens
  set_id { |pair| pair.id.to_s.downcase }

  attributes :access_token, :refresh_token, :token_type, :expires_in, :refresh_expires_in
end
