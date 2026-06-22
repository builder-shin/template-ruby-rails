# frozen_string_literal: true

class BlogPost < ApplicationRecord
  self.table_name = "blog_post"

  # DB 컬럼이 string + CHECK 제약이므로 string-backed enum 으로 선언
  enum :status, {
    draft: "draft",
    published: "published",
    hidden: "hidden",
    deleted: "deleted"
  }, prefix: true

  enum :author_type, {
    personal: "personal",
    enterprise: "enterprise"
  }, prefix: true

  has_many :blog_post_categories, dependent: :destroy
  has_many :blog_categories, through: :blog_post_categories, source: :blog_category
  has_many :blog_views, dependent: :destroy

  validates :author_id, presence: true
  validates :author_type, presence: true
  validates :title, presence: true, length: { maximum: 256 }
  validates :slug, presence: true, uniqueness: true, length: { maximum: 512 }
  validates :content, presence: true
  validates :status, presence: true
  validates :views, presence: true, numericality: { only_integer: true, greater_than_or_equal_to: 0 }
  validates :main_image_size, presence: true, numericality: { only_integer: true, greater_than_or_equal_to: 0 }
end
