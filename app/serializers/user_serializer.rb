# frozen_string_literal: true

# 인증된 본인의 공개 프로필. 정본 UserSerializer(resource_path="/api/v1/users/me")와
# 동일하게 self 링크를 항상 고정 경로로 낸다 — user.id로 조립하지 않는다.
# `GET /api/v1/users/{id}` 라우트는 없다; 이 자원은 "나"에서만 조회된다.
class UserSerializer < ApplicationSerializer
  set_key_transform :camel_lower
  set_type :users
  set_id { |user| user.id.to_s.downcase }

  attributes :email, :is_active
  utc_microsecond_timestamps :created_at, :updated_at

  link :self do |_user|
    "/api/v1/users/me"
  end
end
