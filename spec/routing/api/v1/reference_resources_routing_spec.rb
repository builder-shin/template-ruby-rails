# frozen_string_literal: true

require "rails_helper"

RSpec.describe "Reference resource routes", type: :routing do
  it "defines exactly the two read-only category routes" do
    routes = Rails.application.routes.routes.filter_map do |route|
      next unless route.defaults[:controller] == "api/v1/example_categories"

      [ route.verb, route.path.spec.to_s.delete_suffix("(.:format)"), route.defaults.fetch(:action) ]
    end

    expect(routes).to contain_exactly(
      [ "GET", "/api/v1/categories", "index" ],
      [ "GET", "/api/v1/categories/:id", "show" ]
    )
  end

  it "defines exactly the two read-only tag routes" do
    routes = Rails.application.routes.routes.filter_map do |route|
      next unless route.defaults[:controller] == "api/v1/example_tags"

      [ route.verb, route.path.spec.to_s.delete_suffix("(.:format)"), route.defaults.fetch(:action) ]
    end

    expect(routes).to contain_exactly(
      [ "GET", "/api/v1/tags", "index" ],
      [ "GET", "/api/v1/tags/:id", "show" ]
    )
  end
end
