# frozen_string_literal: true

require "rails_helper"

RSpec.describe "Shared backend indexes" do
  it "indexes default ordering, title ordering and the category foreign key" do
    definitions = ActiveRecord::Base.connection.select_values(<<~SQL)
      SELECT indexdef FROM pg_indexes WHERE schemaname = 'public' AND tablename = 'examples'
    SQL
    expect(definitions.any? { |definition| definition.include?("(created_at DESC, id)") }).to be(true)
    expect(definitions.any? { |definition| definition.include?("(title, id)") }).to be(true)
    expect(definitions.any? { |definition| definition.include?("(category_id)") }).to be(true)
  end

  it "indexes reverse tag lookups and tag deletion cascades" do
    definitions = ActiveRecord::Base.connection.select_values(<<~SQL)
      SELECT indexdef FROM pg_indexes WHERE schemaname = 'public' AND tablename = 'example_taggings'
    SQL
    expect(definitions.any? { |definition| definition.include?("(tag_id)") }).to be(true)
  end
end
