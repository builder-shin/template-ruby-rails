# frozen_string_literal: true

class BlogAuthorPermission < ApplicationRecord
  self.table_name = 'blog_author_permission'

  enum :status, {
    pending: 0,
    approved: 1,
    rejected: 2
  }, prefix: true

  enum :author_type, {
    personal: 0,
    enterprise: 1
  }, prefix: true

  validates :author_id, presence: true
  validates :author_type, presence: true
  validates :status, presence: true
  validates :author_id, uniqueness: { scope: :author_type }
end
