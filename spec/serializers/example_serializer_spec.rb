# frozen_string_literal: true

require "rails_helper"

RSpec.describe ExampleSerializer do
  subject(:document) do
    JSON.parse(described_class.new(example, options).serializable_hash.to_json)
  end

  let(:options) { {} }

  describe "the primary resource" do
    let(:example) { create(:example, :with_category, :with_tags) }

    before do
      example.id = example.id.upcase
    end

    it "serializes the Example contract with canonical links" do
      resource = document.fetch("data")
      canonical_path = "/api/v1/examples/#{example.id.downcase}"

      expect(resource.fetch("type")).to eq("examples")
      expect(resource.fetch("id")).to eq(example.id.downcase)
      expect(resource.fetch("attributes").keys).to eq(
        %w[title description status score createdAt updatedAt]
      )
      expect(resource.fetch("relationships").keys).to eq(%w[category tags])
      expect(resource.fetch("links")).to eq("self" => canonical_path)

      category = resource.dig("relationships", "category")
      expect(category.fetch("data")).to eq(
        "type" => "exampleCategories",
        "id" => example.category_id.downcase
      )
      expect(category.fetch("links")).to eq(
        "self" => "#{canonical_path}/relationships/category",
        "related" => "#{canonical_path}/category"
      )

      tags = resource.dig("relationships", "tags")
      expect(tags.fetch("data").map { |tag| tag.fetch("type") }.uniq).to eq([ "exampleTags" ])
      expect(tags.fetch("data").map { |tag| tag.fetch("id") }).to eq(example.tag_ids.map(&:downcase))
      expect(tags.fetch("links")).to eq(
        "self" => "#{canonical_path}/relationships/tags",
        "related" => "#{canonical_path}/tags"
      )
      expect(document).not_to have_key("included")
    end
  end

  describe "included resources" do
    let(:options) { { include: %i[category tags] } }

    context "when related records exist" do
      let(:example) { create(:example, :with_category, :with_tags) }

      it "includes category and tags without non-canonical self links" do
        included = document.fetch("included")
        category = included.find { |resource| resource.fetch("type") == "exampleCategories" }
        tags = included.select { |resource| resource.fetch("type") == "exampleTags" }

        expect(category.fetch("id")).to eq(example.category_id.downcase)
        expect(category.fetch("attributes")).to eq("name" => example.category.name)
        expect(category).not_to have_key("links")

        expect(tags.map { |resource| resource.fetch("id") }).to eq(example.tag_ids.map(&:downcase))
        expect(tags.map { |resource| resource.fetch("attributes").keys }.uniq).to eq([ [ "name" ] ])
        expect(tags).to all(satisfy { |resource| !resource.key?("links") })
      end
    end

    context "when no related records exist" do
      let(:example) { create(:example) }

      it "returns an empty included array" do
        expect(document.fetch("included")).to eq([])
      end
    end
  end
end
