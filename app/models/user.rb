# frozen_string_literal: true

class User < ApplicationRecord
  has_many :refresh_sessions, dependent: :destroy

  # 이메일 정규화(normalize_email)는 여기서 하지 않는다. 정본은 저장·조회
  # 직전에 컨트롤러/서비스에서 정규화를 부르므로, 모델 콜백으로 옮기면
  # 조회 경로와 저장 경로의 정규화가 갈릴 수 있다.
  validates :email, presence: true, uniqueness: true
  validates :password_hash, presence: true
end
