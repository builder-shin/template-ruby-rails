# frozen_string_literal: true

class BlogView < ApplicationRecord
  self.table_name = 'blog_view'

  belongs_to :blog_post

  validates :blog_post_id, presence: true
  validates :ip_address, length: { maximum: 45 }, allow_blank: true
end
