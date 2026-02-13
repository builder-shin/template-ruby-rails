# frozen_string_literal: true

class BlogCategory < ApplicationRecord
  self.table_name = 'blog_category'

  enum :status, {
    active: 0,
    inactive: 1
  }, prefix: true

  belongs_to :parent, class_name: 'BlogCategory', optional: true
  has_many :children, class_name: 'BlogCategory', foreign_key: :parent_id, dependent: :nullify
  has_many :blog_post_categories, foreign_key: :category_id, dependent: :destroy
  has_many :blog_posts, through: :blog_post_categories

  validates :name, presence: true, length: { maximum: 128 }
  validates :slug, presence: true, uniqueness: true, length: { maximum: 128 }
  validates :level, presence: true
  validates :sort_order, presence: true
  validates :status, presence: true
end
