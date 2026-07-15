# frozen_string_literal: true

class ExampleSerializer < ApplicationSerializer
  set_key_transform :camel_lower
  set_type :examples
  set_id { |example| example.id.to_s.downcase }

  attributes :title, :description, :status, :score, :created_at, :updated_at

  link :self do |example|
    "/api/v1/examples/#{example.id.to_s.downcase}"
  end

  belongs_to :category,
             serializer: ExampleCategorySerializer,
             links: {
               self: lambda { |example|
                 "/api/v1/examples/#{example.id.to_s.downcase}/relationships/category"
               },
               related: ->(example) { "/api/v1/examples/#{example.id.to_s.downcase}/category" }
             }

  has_many :tags,
           serializer: ExampleTagSerializer,
           links: {
             self: lambda { |example|
               "/api/v1/examples/#{example.id.to_s.downcase}/relationships/tags"
             },
             related: ->(example) { "/api/v1/examples/#{example.id.to_s.downcase}/tags" }
           }
end
