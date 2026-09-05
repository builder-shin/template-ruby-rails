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

  describe "identifier normalization" do
    let(:options) { { is_collection: false } }
    let(:example_id) { "AAAAAAAA-AAAA-4AAA-8AAA-AAAAAAAAAAAA" }
    let(:category_id) { "BBBBBBBB-BBBB-4BBB-8BBB-BBBBBBBBBBBB" }
    let(:tag_ids) do
      [
        "CCCCCCCC-CCCC-4CCC-8CCC-CCCCCCCCCCCC",
        "DDDDDDDD-DDDD-4DDD-8DDD-DDDDDDDDDDDD"
      ]
    end
    let(:relationship_record_class) { Struct.new(:id, :name, keyword_init: true) }
    let(:category) { relationship_record_class.new(id: category_id, name: "Controlled Category") }
    let(:tags) do
      tag_ids.map.with_index do |id, index|
        relationship_record_class.new(id: id, name: "Controlled Tag #{index + 1}")
      end
    end
    let(:example) do
      Struct.new(
        :id, :title, :description, :status, :score, :created_at, :updated_at,
        :category_id, :tag_ids, :category, :tags,
        keyword_init: true
      ).new(
        id: example_id,
        title: "Controlled Example",
        description: nil,
        status: "draft",
        score: 0,
        created_at: Time.zone.parse("2026-07-15 00:00:00"),
        updated_at: Time.zone.parse("2026-07-15 00:00:00"),
        category_id: category_id,
        tag_ids: tag_ids,
        category: category,
        tags: tags
      )
    end

    it "lowercases primary, linkage, and canonical link identifiers", :aggregate_failures do
      resource = document.fetch("data")
      canonical_path = "/api/v1/examples/#{example_id.downcase}"

      expect(resource.fetch("id")).to eq(example_id.downcase)
      expect(resource.dig("relationships", "category", "data", "id")).to eq(category_id.downcase)
      expect(resource.dig("relationships", "tags", "data").pluck("id")).to eq(tag_ids.map(&:downcase))
      expect(resource.fetch("links")).to eq("self" => canonical_path)
      expect(resource.dig("relationships", "category", "links")).to eq(
        "self" => "#{canonical_path}/relationships/category",
        "related" => "#{canonical_path}/category"
      )
      expect(resource.dig("relationships", "tags", "links")).to eq(
        "self" => "#{canonical_path}/relationships/tags",
        "related" => "#{canonical_path}/tags"
      )
    end
  end

  describe "included resources" do
    let(:options) { { include: %i[category tags] } }

    context "when related records exist" do
      let(:example) { create(:example, :with_category, :with_tags) }

      it "includes category and tags with their canonical self links" do
        expected = [
          {
            "id" => example.category.id.downcase,
            "type" => "exampleCategories",
            "attributes" => { "name" => example.category.name },
            "links" => { "self" => "/api/v1/categories/#{example.category.id.downcase}" }
          },
          *example.tags.map do |tag|
            {
              "id" => tag.id.downcase,
              "type" => "exampleTags",
              "attributes" => { "name" => tag.name },
              "links" => { "self" => "/api/v1/tags/#{tag.id.downcase}" }
            }
          end
        ]

        expect(document.fetch("included")).to eq(expected)
      end

      it "gives included reference resources a self link" do
        included = document.fetch("included")

        category_entry = included.find { |resource| resource.fetch("type") == "exampleCategories" }
        expect(category_entry.dig("links", "self")).to eq("/api/v1/categories/#{example.category.id.downcase}")

        tag_entry = included.find { |resource| resource.fetch("type") == "exampleTags" }
        expect(tag_entry.dig("links", "self")).to eq("/api/v1/tags/#{tag_entry.fetch("id")}")
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
