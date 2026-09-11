# frozen_string_literal: true

require "rails_helper"

RSpec.describe "deterministic seeds" do
  let(:seed_path) { Rails.root.join("db/seeds.rb") }
  let(:category_id) { "00000000-0000-4000-8000-000000000001" }
  let(:tag_id) { "00000000-0000-4000-8000-000000000002" }
  let(:example_id) { "00000000-0000-4000-8000-000000000003" }

  it "creates the canonical FastAPI graph and repairs it on reexecution" do
    load seed_path

    category = ExampleCategory.find(category_id)
    tag = ExampleTag.find(tag_id)
    seeded_example = Example.find(example_id)
    expect(category.name).to eq("기본 카테고리")
    expect(tag.name).to eq("기본 태그")
    expect(seeded_example).to have_attributes(
      title: "JSON:API 예시",
      description: "JSON:API와 CRUD 동작을 확인하기 위한 기본 데이터입니다.",
      status: "active",
      score: 90,
      category_id: category_id
    )
    expect(seeded_example.tag_ids).to include(tag_id)

    unrelated = create(:example_tag, name: "사용자 태그")
    seeded_example.update!(title: "changed", status: "archived", score: 1, category: nil)
    seeded_example.tags = [ unrelated ]
    category.update!(name: "changed category")
    tag.update!(name: "changed tag")

    expect { load seed_path }.not_to change(Example, :count)

    expect(category.reload.name).to eq("기본 카테고리")
    expect(tag.reload.name).to eq("기본 태그")
    expect(seeded_example.reload).to have_attributes(
      title: "JSON:API 예시",
      description: "JSON:API와 CRUD 동작을 확인하기 위한 기본 데이터입니다.",
      status: "active",
      score: 90,
      category_id: category_id
    )
    expect(seeded_example.tag_ids).to contain_exactly(tag_id, unrelated.id)
  end

  it "rolls back the whole graph if a later seed write fails" do
    allow(Example).to receive(:upsert_all).and_raise(ActiveRecord::RecordInvalid)

    expect { load seed_path }.to raise_error(ActiveRecord::RecordInvalid)

    expect(ExampleCategory.exists?(category_id)).to be(false)
    expect(ExampleTag.exists?(tag_id)).to be(false)
    expect(Example.exists?(example_id)).to be(false)
  end

  it "rolls back earlier seed rows when a canonical natural key belongs to another id" do
    existing_tag = create(:example_tag, name: "기본 태그")

    expect { load seed_path }.to raise_error(ActiveRecord::RecordNotUnique)

    expect(existing_tag.reload.name).to eq("기본 태그")
    expect(ExampleCategory.exists?(category_id)).to be(false)
    expect(ExampleTag.exists?(tag_id)).to be(false)
    expect(Example.exists?(example_id)).to be(false)
  end
end
