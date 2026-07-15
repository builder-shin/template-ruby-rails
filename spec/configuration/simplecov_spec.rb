# frozen_string_literal: true

require "rails_helper"

RSpec.describe "SimpleCov configuration" do
  let(:rails_helper_source) { Rails.root.join("spec/rails_helper.rb").read }

  it "uses the environment minimum with an 80 percent default" do
    expect(rails_helper_source).to include('minimum_coverage ENV.fetch("COVERAGE_MINIMUM", "80").to_f')
    expect(SimpleCov.minimum_coverage.fetch(:line)).to eq(ENV.fetch("COVERAGE_MINIMUM", "80").to_f)
  end

  it "filters exactly the approved generated base files" do
    filters = rails_helper_source.scan(/^\s*add_filter\s+["']([^"']+)["']/).flatten

    expect(filters).to eq(
      [
        "app/channels/application_cable/",
        "app/helpers/application_helper.rb",
        "app/mailers/application_mailer.rb"
      ]
    )
  end
end
