# frozen_string_literal: true

class BlogViewSerializer < ApplicationSerializer
  attributes :id, :blog_post_id, :viewed_at

  belongs_to :blog_post
end
