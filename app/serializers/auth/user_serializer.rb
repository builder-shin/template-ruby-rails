# frozen_string_literal: true

module Auth
  class UserSerializer < ApplicationSerializer
    set_type :user

    attributes :id, :email, :name, :auth_method, :verified_at,
               :mobile, :workspace_id, :job_id, :created_at, :updated_at

    # Note: password_hash is NEVER exposed

    belongs_to :workspace, serializer: Auth::WorkspaceSerializer
    has_many :user_consents, serializer: Auth::UserConsentSerializer
  end
end
