# frozen_string_literal: true

require "rails_helper"
require "bundler"

RSpec.describe "Production dependency contract" do
  it "keeps runtime Swagger serving separate from development and test generation" do
    dependencies = Bundler::Definition
      .build(Rails.root.join("Gemfile"), Rails.root.join("Gemfile.lock"), nil)
      .dependencies
      .index_by(&:name)

    expect(dependencies).not_to have_key("rswag")
    expect(dependencies.fetch("rswag-api").groups).to eq([ :default ])
    expect(dependencies.fetch("rswag-ui").groups).to eq([ :default ])
    expect(dependencies.fetch("rswag-specs").groups).to contain_exactly(:development, :test)
  end
end
