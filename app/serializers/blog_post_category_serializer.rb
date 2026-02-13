# frozen_string_literal: true

class BlogPostCategorySerializer < ApplicationSerializer
  attributes :blog_post_id, :category_id

  belongs_to :blog_post
  belongs_to :blog_category, id_method_name: :category_id
end
