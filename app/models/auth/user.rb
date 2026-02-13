# frozen_string_literal: true

module Auth
  class User < Base
    self.table_name = "auth.users"
    self.primary_key = "id"

    # Relationships
    belongs_to :workspace, class_name: "Auth::Workspace", optional: true
    has_many :user_consents, class_name: "Auth::UserConsent", foreign_key: "user_id"
    has_one :profile, class_name: "::Profile", foreign_key: "user_id", primary_key: "id"

    # Scopes
    scope :verified, -> { where.not(verified_at: nil) }
  end
end
