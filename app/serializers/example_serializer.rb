# frozen_string_literal: true

class ExampleSerializer < ApplicationSerializer
  NormalizedRelationship = Data.define(:id, :name)
  private_constant :NormalizedRelationship

  set_key_transform :camel_lower
  set_type :examples
  set_id { |example| example.id.to_s.downcase }

  attributes :title, :description, :status, :score, :created_at, :updated_at

  link :self do |example|
    "/api/v1/examples/#{example.id.to_s.downcase}"
  end

  belongs_to :category,
             serializer: ExampleCategorySerializer,
             id_method_name: :id,
             links: {
               self: lambda { |example|
                 "/api/v1/examples/#{example.id.to_s.downcase}/relationships/category"
               },
               related: ->(example) { "/api/v1/examples/#{example.id.to_s.downcase}/category" }
             } do |example|
    category = example.category

    if category
      NormalizedRelationship.new(id: category.id.to_s.downcase, name: category.name)
    end
  end

  has_many :tags,
           serializer: ExampleTagSerializer,
           id_method_name: :id,
           links: {
             self: lambda { |example|
               "/api/v1/examples/#{example.id.to_s.downcase}/relationships/tags"
             },
             related: ->(example) { "/api/v1/examples/#{example.id.to_s.downcase}/tags" }
           } do |example|
    example.tags.map do |tag|
      NormalizedRelationship.new(id: tag.id.to_s.downcase, name: tag.name)
    end
  end
end
