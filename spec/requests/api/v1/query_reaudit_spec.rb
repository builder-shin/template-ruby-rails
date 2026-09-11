# frozen_string_literal: true

require "rails_helper"
require "base64"

RSpec.describe "Query re-audit regressions", type: :request do
  %w[GET HEAD].product([ "hello", "{", "[", '{"data":' ]).each do |method, input|
    it "ignores #{input.inspect} body while parsing #{method} filters" do
      category = create(:example_category)
      example = create(:example, category: category)
      path = "/api/v1/examples?filter%5Bcategory.id%5D=#{category.id}"
      environment = Rack::MockRequest.env_for(path, method: method, input: input,
        "CONTENT_TYPE" => "application/vnd.api+json", "HTTP_ACCEPT" => "application/vnd.api+json")
      status, _headers, body = Rails.application.call(environment)
      expect(status).to eq(200), body.each.to_a.join
      expect(JSON.parse(body.each.to_a.join).fetch("data").pluck("id")).to eq([ example.id ]) if method == "GET"
    ensure
      body.close if body.respond_to?(:close)
    end
  end
  it "ignores malformed vendor bodies on collection GET requests" do
    environment = Rack::MockRequest.env_for("/api/v1/examples", method: "GET", input: "hello", "CONTENT_TYPE" => "application/vnd.api+json", "HTTP_ACCEPT" => "application/vnd.api+json")
    status, _headers, body = Rails.application.call(environment)
    expect(status).to eq(200), body.each.to_a.join
  ensure
    body.close if body.respond_to?(:close)
  end
  let(:headers) { { "Accept" => "application/vnd.api+json", "Accept-Language" => "en" } }

  it "accepts exact and range filters for the same field" do
    get "/api/v1/examples?filter[score]=1&filter[score][gte]=0", headers: headers
    expect(response).to have_http_status(:ok)
  end

  it "reports the first invalid pair before later shape conflicts" do
    get "/api/v1/examples?filter[title]=&filter[score]=1&filter[score][exact]=1", headers: headers
    expect(response).to have_http_status(:bad_request)
    expect(JSON.parse(response.body).fetch("errors").first.fetch("source")).to eq("parameter" => "filter[title]")
  end

  [ " 10 ", "1_0", "١٠", "１０", "+10" ].each do |value|
    it "preserves integer grammar #{value.inspect}" do
      get "/api/v1/examples", params: { "filter[score]" => value }, headers: headers
      expect(response).to have_http_status(:ok)
    end
  end

  [ "0000-01-01T00:00:00Z", "2026-02-30T00:00:00Z", "2026-01-01T24:00:00Z", "2026-01-01T00:00:60Z", "0001-01-01T00:00:00+01:00", "9999-12-31T23:59:59-01:00" ].each do |value|
    it "rejects invalid timestamp #{value}" do
      get "/api/v1/examples", params: { "filter[createdAt][gte]" => value }, headers: headers
      expect(response).to have_http_status(:bad_request)
      expect(JSON.parse(response.body).fetch("errors").first).to include("code" => "INVALID_FILTER", "source" => { "parameter" => "filter[createdAt][gte]" })
    end
  end

  [ "2026-01-01 00:00:00+00:00", "2026-01-01T00:00:00+01:60", "20260101T000000Z", "2026-W01-4T00:00:00Z", "2026-01-01T00:00Z", "2026-01-01X00:00:00,123456789Z" ].each do |value|
    it "accepts ISO timestamp #{value}" do
      get "/api/v1/examples", params: { "filter[createdAt][gte]" => value }, headers: headers
      expect(response).to have_http_status(:ok)
    end
  end

  [ "00000000000040008000000000000001", "{00000000-0000-4000-8000-000000000001}", "urn:uuid:00000000-0000-4000-8000-000000000001" ].each do |value|
    it "accepts UUID #{value}" do
      get "/api/v1/examples", params: { "filter[category.id]" => value }, headers: headers
      expect(response).to have_http_status(:ok)
    end
  end

  %w[after before].each do |direction|
    [ [ "score", "2147483648" ], [ "score", "-2147483649" ], [ "score", "not-a-number" ], [ "score", nil ], [ "score", 1 ], [ "createdAt", "0000-01-01T00:00:00Z" ], [ "createdAt", "2026-01-01T00:00:00" ], [ "status", "unknown" ], [ "title", nil ] ].each do |sort, value|
      it "rejects typed #{sort} #{direction} cursor #{value.inspect}" do
        cursor = Base64.urlsafe_encode64(JSON.generate({ "s" => "#{sort}:asc,id:asc", "v" => [ value, "00000000-0000-4000-8000-000000000001" ] }), padding: false)
        get "/api/v1/examples", params: { "sort" => sort, "page[#{direction}]" => cursor }, headers: headers
        expect(response).to have_http_status(:bad_request)
        expect(JSON.parse(response.body).fetch("errors").first).to include("code" => "INVALID_PAGE", "source" => { "parameter" => "page[#{direction}]" })
      end
    end
  end

  [ 'application/vnd.api+json;profile=abc', 'application/vnd.api+json;profile=""', 'application/vnd.api+json;profile="relative"', 'application/vnd.api+json;q=bad,*/*', 'application/vnd.api+json;q=1.0000,*/*' ].each do |accept|
    it "accepts supported profile or wildcard fallback #{accept}" do
      get "/api/v1/examples", headers: headers.merge("Accept" => accept)
      expect(response).to have_http_status(:ok)
    end
  end

  it "orders all statuses and round trips ascending/descending cursor links" do
    %w[draft active archived].each do |status|
      2.times { create(:example, status: status, title: "same", score: 1) }
    end
    %w[title -title score -score status -status createdAt -createdAt updatedAt -updatedAt].each do |sort|
      get "/api/v1/examples", params: { "sort" => sort, "page[size]" => "100" }, headers: headers
      expected = JSON.parse(response.body).fetch("data")
      statuses = expected.map { |row| row.dig("attributes", "status") }
      if sort.delete_prefix("-") == "status"
        expect(statuses).to eq(sort == "status" ? %w[draft draft active active archived archived] : %w[archived archived active active draft draft])
      end
      %w[after before].each do |direction|
        get "/api/v1/examples", params: { "sort" => sort, "page[#{direction}]" => "", "page[size]" => "1" }, headers: headers
        rows = []
        8.times do
          expect(response).to have_http_status(:ok)
          rows.concat(JSON.parse(response.body).fetch("data"))
          link = JSON.parse(response.body).dig("links", direction == "after" ? "next" : "prev")
          break unless link
          get link, headers: headers
        end
        expect(rows).to eq(direction == "after" ? expected : expected.reverse)
      end
      get "/api/v1/examples", params: { "sort" => sort, "page[after]" => "", "page[size]" => "1" }, headers: headers
      link = JSON.parse(response.body).dig("links", "next")
      raw = URI.decode_www_form(URI(link).query).to_h.fetch("page[after]")
      payload = JSON.parse(Base64.urlsafe_decode64(raw))
      invalid_values = [ nil, true, 1, {}, [] ]
      invalid_values.concat([ "2147483648", "-2147483649", "bad" ]) if sort.include?("score")
      invalid_values.concat([ "0000-01-01T00:00:00Z", "2026-02-30T00:00:00Z", "0001-01-01T00:00:00+01:00" ]) if sort.include?("At")
      invalid_values << "unknown" if sort.include?("status")
      %w[after before].each do |direction|
        invalid_values.each do |value|
          payload["v"][0] = value
          cursor = Base64.urlsafe_encode64(JSON.generate(payload), padding: false)
          get "/api/v1/examples", params: { "sort" => sort, "page[#{direction}]" => cursor }, headers: headers
          expect(response).to have_http_status(:bad_request)
          expect(JSON.parse(response.body).fetch("errors").first.fetch("source")).to eq("parameter" => "page[#{direction}]")
        end
      end
    end
  end
end
