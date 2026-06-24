# frozen_string_literal: true

class BlogPostCategory < ApplicationRecord
  self.table_name = "blog_post_category"
  self.primary_key = [ :blog_post_id, :category_id ]

  belongs_to :blog_post
  belongs_to :blog_category, foreign_key: :category_id

  validates :blog_post_id, presence: true
  validates :category_id, presence: true
end
