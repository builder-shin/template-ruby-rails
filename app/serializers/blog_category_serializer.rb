# frozen_string_literal: true

class BlogCategorySerializer < ApplicationSerializer
  attributes :id, :name, :slug, :level, :sort_order, :status,
             :parent_id, :created_at, :updated_at

  belongs_to :parent, serializer: :blog_category
  has_many :children
  has_many :blog_posts
end
