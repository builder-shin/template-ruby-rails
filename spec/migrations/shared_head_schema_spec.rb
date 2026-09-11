# frozen_string_literal: true

require "rails_helper"

RSpec.describe "Shared migration head schema" do
  it "keeps required status and score without database defaults after schema loading" do
    columns = ActiveRecord::Base.connection.columns("examples").index_by(&:name)
    expect(columns.fetch("status").sql_type).to eq("example_status")
    expect(columns.fetch("status").default).to be_nil
    expect(columns.fetch("score").default).to be_nil
    expect(columns.fetch("status").null).to be(false)
    expect(columns.fetch("score").null).to be(false)
  end
end
