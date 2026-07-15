# frozen_string_literal: true

require "rails_helper"

RSpec.describe "Example routes", type: :routing do
  let(:resource_id) { "11111111-1111-4111-8111-111111111111" }

  it "defines exactly the six CRUD and upsert action routes" do
    routes = Rails.application.routes.routes.filter_map do |route|
      next unless route.defaults[:controller] == "api/v1/examples"

      [ route.verb, route.defaults.fetch(:action) ]
    end

    expect(routes).to contain_exactly(
      [ "GET", "index" ],
      [ "POST", "create" ],
      [ "GET", "show" ],
      [ "PATCH", "update" ],
      [ "PUT", "upsert" ],
      [ "DELETE", "destroy" ]
    )
  end

  it "recognizes every method and path as the intended action" do
    mappings = {
      [ :get, "/api/v1/examples" ] => "index",
      [ :post, "/api/v1/examples" ] => "create",
      [ :get, "/api/v1/examples/#{resource_id}" ] => "show",
      [ :patch, "/api/v1/examples/#{resource_id}" ] => "update",
      [ :put, "/api/v1/examples/#{resource_id}" ] => "upsert",
      [ :delete, "/api/v1/examples/#{resource_id}" ] => "destroy"
    }

    mappings.each do |(method, path), action|
      expect(Rails.application.routes.recognize_path(path, method: method)).to include(
        controller: "api/v1/examples",
        action: action
      )
    end
  end

  it "does not expose Rails new or edit actions" do
    example_actions = Rails.application.routes.routes.filter_map do |route|
      route.defaults[:action] if route.defaults[:controller] == "api/v1/examples"
    end

    expect(example_actions).not_to include("new", "edit")
    expect(
      Rails.application.routes.recognize_path("/api/v1/examples/new", method: :get)
    ).to include(controller: "api/v1/examples", action: "show", id: "new")
    expect(
      Rails.application.routes.recognize_path("/api/v1/examples/#{resource_id}/edit", method: :get)
    ).to include(controller: "application", action: "route_not_found")
  end
end
