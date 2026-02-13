# frozen_string_literal: true

class BlogPostSerializer < ApplicationSerializer
  attributes :id, :author_id, :author_type, :title, :slug, :content,
             :description, :meta_description, :main_image, :main_image_size,
             :tags, :status, :views, :publish_date,
             :created_at, :updated_at

  has_many :blog_categories
  has_many :blog_views
end
