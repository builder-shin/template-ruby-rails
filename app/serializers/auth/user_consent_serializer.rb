# frozen_string_literal: true

module Auth
  class UserConsentSerializer < ApplicationSerializer
    set_type :user_consent

    attributes :id, :user_id, :consent_type, :is_agreed, :consent_version,
               :agreed_at, :withdrawn_at, :created_at, :updated_at

    # Note: ip_address and user_agent are NEVER exposed

    belongs_to :user, serializer: Auth::UserSerializer
  end
end
