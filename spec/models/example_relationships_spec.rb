# frozen_string_literal: true

require "rails_helper"

RSpec.describe "Example relationships", type: :model do
  it "allows an example without a category" do
    expect(build(:example, category: nil)).to be_valid
  end

  it "nullifies the category reference in the database when the category is deleted" do
    category = create(:example_category)
    example = create(:example, category: category)

    category.delete

    expect(example.reload.category_id).to be_nil
  end

  it "deletes taggings in the database when the example is deleted" do
    tagging = create(:example_tagging)

    tagging.example.delete

    expect(ExampleTagging.exists?(example_id: tagging.example_id, tag_id: tagging.tag_id)).to be(false)
  end

  it "deletes taggings in the database when the tag is deleted" do
    tagging = create(:example_tagging)

    tagging.example_tag.delete

    expect(ExampleTagging.exists?(example_id: tagging.example_id, tag_id: tagging.tag_id)).to be(false)
  end

  it "rejects duplicate category names" do
    category = create(:example_category)
    duplicate = build(:example_category, name: category.name)

    expect(duplicate).not_to be_valid
    expect(duplicate.errors[:name]).to be_present
  end

  it "rejects a blank category name" do
    expect(build(:example_category, name: " ")).not_to be_valid
  end

  it "rejects duplicate tag names" do
    tag = create(:example_tag)
    duplicate = build(:example_tag, name: tag.name)

    expect(duplicate).not_to be_valid
    expect(duplicate.errors[:name]).to be_present
  end

  it "rejects a blank tag name" do
    expect(build(:example_tag, name: " ")).not_to be_valid
  end

  it "requires both tagging associations" do
    expect(build(:example_tagging, example: nil)).not_to be_valid
    expect(build(:example_tagging, example_tag: nil)).not_to be_valid
  end

  it "rejects a duplicate example-tag pair" do
    tagging = create(:example_tagging)
    duplicate = build(:example_tagging, example: tagging.example, example_tag: tagging.example_tag)

    expect(duplicate).not_to be_valid
    expect(duplicate.errors[:tag_id]).to be_present
  end

  it "provides explicit category and tag traits" do
    categorized = create(:example, :with_category)
    tagged = create(:example, :with_tags, tags_count: 2)

    expect(categorized.category).to be_persisted
    expect(tagged.tags.count).to eq(2)
  end
end
