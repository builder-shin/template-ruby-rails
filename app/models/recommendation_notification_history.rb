# frozen_string_literal: true

class RecommendationNotificationHistory < ApplicationRecord
  self.table_name = 'recommendation_notification_history'
  self.inheritance_column = nil  # 'type' 컬럼을 STI가 아닌 일반 컬럼으로 사용

  # sender_id는 추천 컨텍스트에서 job_post_id와 동일
  # recipient_id는 Auth::User의 id (FDW read-only이므로 belongs_to 대신 ID만 사용)
  belongs_to :job_post, optional: true

  # Validations
  validates :recipient_email, presence: true, length: { maximum: 255 }
  validates :recipient_id, presence: true
  validates :sender_id, presence: true
  validates :sent_at, presence: true
  validates :type, presence: true, length: { maximum: 50 }
end
