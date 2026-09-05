# frozen_string_literal: true

class User < ApplicationRecord
  has_many :refresh_sessions, dependent: :destroy

  # 이메일 정규화(normalize_email)는 여기서 하지 않는다. 정본은 저장·조회
  # 직전에 컨트롤러/서비스에서 정규화를 부르므로, 모델 콜백으로 옮기면
  # 조회 경로와 저장 경로의 정규화가 갈릴 수 있다.
  validates :email, presence: true
  # uniqueness: true를 의도적으로 두지 않는다(Task 5). 그 검증기는 INSERT 전에
  # 먼저 SELECT로 조회해 보는 사전 조회다 — 정확히 스펙 6.7이 금지하는
  # "조회와 삽입 사이의 경합"을 모델 레이어에서 재도입한다. 더 나쁜 점: 이
  # 사전 조회가 있으면 순차적인(경합이 없는) 흔한 case조차 DB의 유니크
  # 인덱스가 아니라 이 검증기가 먼저 걸려 `ActiveRecord::RecordInvalid`를
  # 던진다 — `AuthController#register`는 `ActiveRecord::RecordNotUnique`만
  # 붙잡아 409 EMAIL_ALREADY_REGISTERED로 바꾸므로, uniqueness: true가 남아
  # 있으면 그 흔한 case가 422 VALIDATION_ERROR로 새 나가고 진짜 동시 가입
  # 경합에서만 우연히 409가 나오는(뮤테이션 테스트로도 못 잡는) 상태가 된다.
  # 유니크는 오직 DB 유니크 인덱스(index_users_on_email)로만 강제한다 —
  # spec/models/user_spec.rb의 "database unique index" 테스트, 그리고
  # AuthController#register의 RecordNotUnique 처리 참고.
  validates :password_hash, presence: true
end
