# frozen_string_literal: true

require "rails_helper"

RSpec.describe "Example routes", type: :routing do
  let(:resource_id) { "11111111-1111-4111-8111-111111111111" }

  it "defines exactly the fourteen CRUD, upsert, relationship, and related routes" do
    routes = Rails.application.routes.routes.filter_map do |route|
      next unless route.defaults[:controller] == "api/v1/examples"

      [ route.verb, route.path.spec.to_s.delete_suffix("(.:format)"), route.defaults.fetch(:action) ]
    end

    expect(routes).to contain_exactly(
      [ "GET", "/api/v1/examples", "index" ],
      [ "POST", "/api/v1/examples", "create" ],
      [ "GET", "/api/v1/examples/:id", "show" ],
      [ "PATCH", "/api/v1/examples/:id", "update" ],
      [ "PUT", "/api/v1/examples/:id", "upsert" ],
      [ "DELETE", "/api/v1/examples/:id", "destroy" ],
      [ "GET", "/api/v1/examples/:id/relationships/category", "category_relationship" ],
      [ "PATCH", "/api/v1/examples/:id/relationships/category", "replace_category_relationship" ],
      [ "GET", "/api/v1/examples/:id/category", "related_category" ],
      [ "GET", "/api/v1/examples/:id/relationships/tags", "tags_relationship" ],
      [ "POST", "/api/v1/examples/:id/relationships/tags", "add_tags_relationship" ],
      [ "PATCH", "/api/v1/examples/:id/relationships/tags", "replace_tags_relationship" ],
      [ "DELETE", "/api/v1/examples/:id/relationships/tags", "remove_tags_relationship" ],
      [ "GET", "/api/v1/examples/:id/tags", "related_tags" ]
    )
  end

  it "recognizes every method and path as the intended action" do
    mappings = {
      [ :get, "/api/v1/examples" ] => "index",
      [ :post, "/api/v1/examples" ] => "create",
      [ :get, "/api/v1/examples/#{resource_id}" ] => "show",
      [ :patch, "/api/v1/examples/#{resource_id}" ] => "update",
      [ :put, "/api/v1/examples/#{resource_id}" ] => "upsert",
      [ :delete, "/api/v1/examples/#{resource_id}" ] => "destroy",
      [ :get, "/api/v1/examples/#{resource_id}/relationships/category" ] => "category_relationship",
      [ :patch, "/api/v1/examples/#{resource_id}/relationships/category" ] =>
        "replace_category_relationship",
      [ :get, "/api/v1/examples/#{resource_id}/category" ] => "related_category",
      [ :get, "/api/v1/examples/#{resource_id}/relationships/tags" ] => "tags_relationship",
      [ :post, "/api/v1/examples/#{resource_id}/relationships/tags" ] => "add_tags_relationship",
      [ :patch, "/api/v1/examples/#{resource_id}/relationships/tags" ] => "replace_tags_relationship",
      [ :delete, "/api/v1/examples/#{resource_id}/relationships/tags" ] => "remove_tags_relationship",
      [ :get, "/api/v1/examples/#{resource_id}/tags" ] => "related_tags"
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

  it "does not expose routes for relationship names outside the allowlist" do
    expect(
      Rails.application.routes.recognize_path(
        "/api/v1/examples/#{resource_id}/relationships/privateItems",
        method: :get
      )
    ).to include(controller: "application", action: "route_not_found")
    expect(
      Rails.application.routes.recognize_path(
        "/api/v1/examples/#{resource_id}/relationships/privateItems",
        method: :patch
      )
    ).to include(controller: "application", action: "route_not_found")
  end
end
