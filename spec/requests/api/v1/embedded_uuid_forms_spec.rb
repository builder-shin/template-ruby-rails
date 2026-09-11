# frozen_string_literal: true

require "rails_helper"

RSpec.describe "Embedded relationship UUID normalization", type: :request do
  before { mock_bearer_user }

  def alias_for(id, form)
    case form
    when :urn then "urn:uuid:#{id.upcase}"
    when :braces then "{{#{id.delete('-')}}}"
    when :unicode then id.tr("0123456789", "٠١٢٣٤٥٦٧٨٩")
    when :plus then "+#{id.delete('-')[1..]}"
    end
  end

  %i[post patch put upsert].each do |operation|
    %i[urn braces unicode plus].each do |form|
      it "normalizes #{form} category and tags on #{operation}" do
        category = create(:example_category, id: "0195c1a0-0000-7000-8000-000000000901")
        tag = create(:example_tag, id: "0195c1a0-0000-7000-8000-000000000902")
        example = create(:example) if %i[patch put].include?(operation)
        id = example&.id || SecureRandom.uuid
        data = { type: "examples", attributes: { title: "Normalized", status: "active", score: 42 }, relationships: {
          category: { data: { type: "exampleCategories", id: alias_for(category.id, form) } },
          tags: { data: [ { type: "exampleTags", id: alias_for(tag.id, form), meta: { source: "test" } } ] }
        } }
        data[:id] = id unless operation == :post
        path = operation == :post ? "/api/v1/examples" : "/api/v1/examples/#{id}"
        public_send(operation == :upsert ? :put : operation, path, params: { data: data }.to_json,
          headers: jsonapi_headers.merge(auth_bearer_headers))
        expect(response.status).to eq(%i[post upsert].include?(operation) ? 201 : 200), response.body
        result = parsed_body.fetch("data")
        stored = Example.find(result.fetch("id"))
        expect(stored.category_id).to eq(category.id)
        expect(stored.tags.pluck(:id)).to eq([ tag.id ])
        expect(result.dig("relationships", "category", "data", "id")).to eq(category.id)
        expect(result.dig("relationships", "tags", "data").pluck("id")).to eq([ tag.id ])
      end
    end

    it "rolls back #{operation} when a later aliased relationship is missing" do
      old_category = create(:example_category)
      old_tag = create(:example_tag)
      category = create(:example_category)
      example = create(:example, category: old_category, title: "Original", tags: [ old_tag ]) if %i[patch put].include?(operation)
      id = example&.id || SecureRandom.uuid
      data = { type: "examples", attributes: { title: "Must not save", status: "active", score: 42 }, relationships: {
        category: { data: { type: "exampleCategories", id: "urn:uuid:#{category.id}" } },
        tags: { data: [ { type: "exampleTags", id: "urn:uuid:#{SecureRandom.uuid}" } ] }
      } }
      data[:id] = id unless operation == :post
      count = Example.count
      path = operation == :post ? "/api/v1/examples" : "/api/v1/examples/#{id}"
      public_send(operation == :upsert ? :put : operation, path, params: { data: data }.to_json,
        headers: jsonapi_headers.merge(auth_bearer_headers))
      expect(response.status).to eq(404), response.body
      expect(parsed_body.dig("errors", 0, "code")).to eq("RELATIONSHIP_RESOURCE_NOT_FOUND")
      expect(parsed_body.dig("errors", 0, "source", "pointer")).to eq("/data/relationships/tags/data/0/id")
      expect(Example.count).to eq(count)
      if example
        expect(example.reload.title).to eq("Original")
        expect(example.category_id).to eq(old_category.id)
        expect(example.tags.pluck(:id)).to eq([ old_tag.id ])
      end
    end
  end
end
