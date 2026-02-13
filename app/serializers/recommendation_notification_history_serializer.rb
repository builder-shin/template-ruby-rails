# frozen_string_literal: true

class RecommendationNotificationHistorySerializer < ApplicationSerializer
  attributes :id, :sender_id, :recipient_id, :job_post_id, :type, :recipient_email, :sent_at, :created_at

  # belongs_to :sender - User는 외부 인증 서비스에서 관리
  # belongs_to :recipient - User는 외부 인증 서비스에서 관리
  belongs_to :job_post
end
