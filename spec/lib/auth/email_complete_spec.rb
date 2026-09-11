# frozen_string_literal: true

require "rails_helper"

RSpec.describe "Complete email contract" do
  JSON.parse(File.read(Rails.root.join("spec/fixtures/auth-email-vectors.json"))).each do |vector|
    it "validates and normalizes #{vector.fetch('input').inspect}" do
      controller = Api::V1::AuthController.new
      action = -> { controller.send(:normalized_email!, { "email" => vector.fetch("input") }) }
      if vector.fetch("normalized").nil?
        expect(&action).to raise_error(JsonApiError)
      else
        expect(action.call).to eq(vector.fetch("normalized"))
      end
    end
  end
end
