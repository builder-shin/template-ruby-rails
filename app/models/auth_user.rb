# frozen_string_literal: true

class AuthUser
  include ActiveModel::API
  include ActiveModel::Attributes

  attribute :id, :string
  attribute :email, :string
  attribute :name, :string
  attribute :workspace_id, :string
  attribute :workspace_kind, :string
  attribute :workspace_role, :string
  attribute :member_status, :string

  def personal?
    workspace_kind == "personal"
  end

  def enterprise?
    workspace_kind == "enterprise"
  end

  def active?
    member_status == "active"
  end
end
