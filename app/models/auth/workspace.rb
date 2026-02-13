# frozen_string_literal: true

module Auth
  class Workspace < Base
    self.table_name = "auth.workspaces"
    self.primary_key = "id"

    # Relationships
    has_many :users, class_name: "Auth::User", foreign_key: "workspace_id"

    # Scopes
    scope :personal, -> { where(kind: "personal") }
    scope :enterprise, -> { where(kind: "enterprise") }
    scope :approved, -> { where(status: "approved") }
  end
end
