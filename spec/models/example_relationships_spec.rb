# frozen_string_literal: true

require "rails_helper"

RSpec.describe "Example relationships", type: :model do
  # 태그 조회 순서는 **태그 id 오름차순**으로 고정돼 있다.
  #
  # 고치기 전에는 명시적 정렬이 없어 Postgres 의 계획에 따라 순서가 흔들렸다.
  # 정본(FastAPI)이 조회에서 내는 순서가 id 오름차순이고, 이 저장소의
  # `.../examples/:id/tags` 라우트도 이미 같은 키로 정렬한다.
  #
  # 픽스처는 **세 순서를 일부러 전부 다르게** 만든다 - id 오름차순, 이름
  # 오름차순, 붙인 순서가 각각 다른 답을 내야 정렬 키를 바꿔치기한 뮤턴트가
  # 죽는다. 셋이 우연히 같으면 이 스펙은 속이 빈다.
  describe "태그 조회 순서" do
    # id 오름차순: alpha, bravo, charlie
    # 이름 오름차순: charlie(probe-order 001), bravo(probe-order 002), alpha(probe-order 003)
    let!(:alpha) { create(:example_tag, id: "44440000-0000-4000-8000-000000000001", name: "probe-order 003 alpha") }
    let!(:bravo) { create(:example_tag, id: "44440000-0000-4000-8000-000000000002", name: "probe-order 002 bravo") }
    let!(:charlie) { create(:example_tag, id: "44440000-0000-4000-8000-000000000003", name: "probe-order 001 charlie") }

    def example_with_tags_attached_in(order)
      example = create(:example)
      example.tag_ids = order.map(&:id)
      example.save!
      Example.find(example.id)
    end

    it "픽스처가 세 순서를 실제로 다르게 만든다" do
      by_id = [ alpha, bravo, charlie ].sort_by(&:id).map(&:name)
      by_name = [ alpha, bravo, charlie ].sort_by(&:name).map(&:name)

      expect(by_id).not_to eq(by_name)
    end

    [
      [ "붙인 순서가 id 순서와 같을 때", ->(tags) { tags } ],
      [ "붙인 순서가 id 순서의 역일 때", ->(tags) { tags.reverse } ],
      [ "붙인 순서가 이름 순서일 때", ->(tags) { tags.sort_by(&:name) } ]
    ].each do |label, arrange|
      it "#{label}도 id 오름차순으로 낸다" do
        tags = [ alpha, bravo, charlie ]
        example = example_with_tags_attached_in(arrange.call(tags))

        expect(example.tags.map(&:id)).to eq(tags.sort_by(&:id).map(&:id))
      end
    end

    it "관련 자원 라우트가 쓰는 정렬 키와 같다 - 같은 관계를 어느 쪽으로 물어도 순서가 같다" do
      example = example_with_tags_attached_in([ charlie, alpha, bravo ])

      # JsonapiRelationships#related_collection_payload 가 쓰는 것과 같은 스코프.
      expect(example.tags.map(&:id)).to eq(example.tags.reorder(:id).map(&:id))
    end
  end

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

  it "rejects category and tag names longer than 200 characters" do
    expect(build(:example_category, name: "c" * 201)).not_to be_valid
    expect(build(:example_tag, name: "t" * 201)).not_to be_valid
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
