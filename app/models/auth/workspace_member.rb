# frozen_string_literal: true

module Auth
  class WorkspaceMember < Base
    self.table_name = "auth.workspace_members"

    # 복합 PK (workspace_id + user_id)
    self.primary_key = [:workspace_id, :user_id]

    belongs_to :workspace, class_name: "Auth::Workspace", foreign_key: "workspace_id"
    belongs_to :user, class_name: "Auth::User", foreign_key: "user_id"

    scope :owners, -> { where(role: "owner") }
    scope :approved, -> { where(member_status: "approved") }
  end
end
