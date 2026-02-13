# frozen_string_literal: true

module Auth
  class WorkspaceSerializer < ApplicationSerializer
    set_type :workspace

    attributes :id, :kind, :name, :domain, :status, :created_at, :updated_at

    # Note: invite_code is excluded for security
  end
end
