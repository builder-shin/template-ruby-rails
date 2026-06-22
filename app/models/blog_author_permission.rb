# frozen_string_literal: true

class BlogAuthorPermission < ApplicationRecord
  self.table_name = "blog_author_permission"

  # DB 컬럼이 string + CHECK 제약이므로 string-backed enum 으로 선언
  enum :status, {
    pending: "pending",
    approved: "approved",
    rejected: "rejected"
  }, prefix: true

  enum :author_type, {
    personal: "personal",
    enterprise: "enterprise"
  }, prefix: true

  validates :author_id, presence: true
  validates :author_type, presence: true
  validates :status, presence: true
  validates :author_id, uniqueness: { scope: :author_type }
end
