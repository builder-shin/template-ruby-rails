# frozen_string_literal: true

module Auth
  class UserConsent < Base
    self.table_name = "auth.user_consents"
    self.primary_key = "id"

    CONSENT_TYPES = %w[
      terms_of_service
      privacy_policy
      age_verification
      marketing
      news_email
      news_sms
      position_recommend_email
      position_recommend_sms
      enterprise_marketing
    ].freeze

    # Relationships
    belongs_to :user, class_name: "Auth::User"

    # Scopes
    scope :active, -> { where(withdrawn_at: nil) }
    scope :agreed, -> { where(is_agreed: true) }
    scope :for_type, ->(type) { where(consent_type: type) }
  end
end
