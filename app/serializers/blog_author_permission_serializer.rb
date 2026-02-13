# frozen_string_literal: true

class BlogAuthorPermissionSerializer < ApplicationSerializer
  attributes :id, :author_id, :author_type, :status,
             :requested_at, :processed_at, :processed_by,
             :created_at, :updated_at
end
