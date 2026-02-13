# frozen_string_literal: true

class BlogPost < ApplicationRecord
  self.table_name = 'blog_post'

  enum :status, {
    draft: 0,
    published: 1,
    hidden: 2,
    deleted: 3
  }, prefix: true

  enum :author_type, {
    personal: 0,
    enterprise: 1
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
