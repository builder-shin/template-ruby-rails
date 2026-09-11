# frozen_string_literal: true

require "rails_helper"

RSpec.describe Example, type: :model do
  describe "validations" do
    subject(:example) { build(:example) }

    it "rejects an empty title" do
      example.title = ""

      expect(example).not_to be_valid
      expect(example.errors[:title]).to be_present
    end

    it "rejects a title longer than 200 characters" do
      example.title = "a" * 201

      expect(example).not_to be_valid
      expect(example.errors[:title]).to be_present
    end

    it "allows a nil description" do
      example.description = nil

      expect(example).to be_valid
    end

    it "stores every supported status" do
      %w[draft active archived].each do |status|
        record = create(:example, status: status)

        expect(record.reload.status).to eq(status)
      end
    end

    # 선언 밖 값은 **대입에서 raise 하지 않고 검증에서** 잡힌다.
    # 대입이 ArgumentError 를 내면 컨트롤러에서 500 이 되기 때문이다
    # (app/models/example.rb 의 validate: true 주석 참고).
    it "rejects an unsupported status at validation, not at assignment" do
      expect { example.status = "probe-lab-undeclared" }.not_to raise_error

      expect(example).not_to be_valid
      expect(example.errors.attribute_names).to include(:status)
    end

    it "allows scores at both boundaries" do
      expect(build(:example, score: 0)).to be_valid
      expect(build(:example, score: 100)).to be_valid
    end

    it "rejects scores outside the allowed range" do
      expect(build(:example, score: -1)).not_to be_valid
      expect(build(:example, score: 101)).not_to be_valid
    end

    it "rejects a non-integer score" do
      expect(build(:example, score: 1.5)).not_to be_valid
    end
  end

  describe "factory" do
    it "creates a valid UUID-backed record with defaults and no implicit relationships" do
      example = create(:example)

      expect(example).to be_valid
      expect(example.id).to match(/\A[0-9a-f]{8}-[0-9a-f]{4}-[1-5][0-9a-f]{3}-[89ab][0-9a-f]{3}-[0-9a-f]{12}\z/i)
      expect(example.status).to eq("draft")
      expect(example.score).to eq(0)
      expect(example.category).to be_nil
      expect(example.example_taggings).to be_empty
    end
  end
end
