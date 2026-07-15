# frozen_string_literal: true

require "rails_helper"
require "uri"

RSpec.describe "Example JSON:API query contract", type: :request do
  PROBE_PATH = "/api/__task_six__/examples"
  LEGACY_PROBE_PATH = "/api/__task_six__/legacy_examples"
  EXAMPLE_IDS = %w[
    00000000-0000-4000-8000-000000000001
    00000000-0000-4000-8000-000000000002
    00000000-0000-4000-8000-000000000003
    00000000-0000-4000-8000-000000000004
  ].freeze

  before do
    stub_const("TaskSixExamplesQueryProbeController", Class.new(ApiController) do
      def klass
        Example
      end

      private

      def query_contract
        {
          filters: {
            "title" => %w[exact contains],
            "status" => %w[exact in],
            "score" => %w[exact gt gte lt lte in],
            "category.id" => %w[exact in isNull],
            "createdAt" => %w[exact gt gte lt lte]
          },
          sorts: %w[title status score createdAt updatedAt],
          includes: %w[category tags]
        }
      end
    end)
    stub_const("TaskSixLegacyExamplesProbeController", Class.new(ApiController) do
      def klass
        Example
      end
    end)

    Rails.application.routes.draw do
      get PROBE_PATH, to: "task_six_examples_query_probe#index"
      get LEGACY_PROBE_PATH, to: "task_six_legacy_examples_probe#index"
    end
  end

  after do
    Rails.application.reload_routes!
  end

  let(:category_one) { create(:example_category, name: "Category one") }
  let(:category_two) { create(:example_category, name: "Category two") }
  let(:tag_one) { create(:example_tag, name: "Tag one") }
  let(:tag_two) { create(:example_tag, name: "Tag two") }
  let(:first_time) { Time.zone.parse("2026-07-11T12:00:00Z") }
  let(:second_time) { Time.zone.parse("2026-07-12T12:00:00Z") }
  let(:third_time) { Time.zone.parse("2026-07-13T12:00:00Z") }
  let(:fourth_time) { Time.zone.parse("2026-07-14T12:00:00Z") }

  let!(:stored_examples) do
    examples = [
      create(
        :example,
        id: EXAMPLE_IDS.fetch(0),
        title: "Alpha%_Literal",
        status: "draft",
        score: 10,
        category: category_one,
        created_at: first_time,
        updated_at: fourth_time
      ),
      create(
        :example,
        id: EXAMPLE_IDS.fetch(1),
        title: "Bravo",
        status: "active",
        score: 20,
        category: category_two,
        created_at: second_time,
        updated_at: third_time
      ),
      create(
        :example,
        id: EXAMPLE_IDS.fetch(2),
        title: "Charlie",
        status: "active",
        score: 30,
        category: nil,
        created_at: third_time,
        updated_at: second_time
      ),
      create(
        :example,
        id: EXAMPLE_IDS.fetch(3),
        title: "Delta",
        status: "archived",
        score: 40,
        category: category_one,
        created_at: fourth_time,
        updated_at: first_time
      )
    ]

    create(:example_tagging, example: examples.fetch(0), example_tag: tag_one)
    create(:example_tagging, example: examples.fetch(1), example_tag: tag_two)
    create(:example_tagging, example: examples.fetch(2), example_tag: tag_one)
    create(:example_tagging, example: examples.fetch(2), example_tag: tag_two)
    examples
  end

  def request_document(query = nil)
    path = query.nil? ? PROBE_PATH : "#{PROBE_PATH}?#{query}"
    get path, headers: jsonapi_headers

    expect(response).to have_http_status(:ok)
    expect(response.headers.fetch("Content-Type")).to eq(JsonapiRequestHelper::JSONAPI_MEDIA_TYPE)
    parsed_body
  end

  def requested_ids(query = nil)
    request_document(query).fetch("data").pluck("id")
  end

  def ids_at(*indexes)
    indexes.map { |index| stored_examples.fetch(index).id.downcase }
  end

  def encoded(value)
    URI.encode_www_form_component(value)
  end

  def decoded_link_query(link)
    URI.decode_www_form(URI.parse(link).query).to_h
  end

  def expect_query_error(query, code:, parameter:)
    get "#{PROBE_PATH}?#{query}", headers: jsonapi_headers
    document = parsed_body

    expect(response).to have_http_status(:bad_request)
    expect(response.headers.fetch("Content-Type")).to eq(JsonapiRequestHelper::JSONAPI_MEDIA_TYPE)
    expect(document).to have_key("errors"), "#{query.inspect} returned #{document.inspect}"
    error = document.fetch("errors").first
    expect(error).to include("status" => "400", "code" => code)
    expect(error.fetch("source")).to eq("parameter" => parameter)
  end

  it "applies every allowlisted filter and operator" do
    cases = [
      [ "title exact", "filter[title]=Bravo", ids_at(1) ],
      [ "title contains", "filter[title][contains]=#{encoded('%_')}", ids_at(0) ],
      [ "status exact", "filter[status]=active", ids_at(2, 1) ],
      [ "status in", "filter[status][in]=draft,archived", ids_at(3, 0) ],
      [ "score exact", "filter[score]=20", ids_at(1) ],
      [ "score gt", "filter[score][gt]=20", ids_at(3, 2) ],
      [ "score gte", "filter[score][gte]=30", ids_at(3, 2) ],
      [ "score lt", "filter[score][lt]=20", ids_at(0) ],
      [ "score lte", "filter[score][lte]=20", ids_at(1, 0) ],
      [ "score in", "filter[score][in]=10,40", ids_at(3, 0) ],
      [ "category exact", "filter[category.id]=#{category_one.id}", ids_at(3, 0) ],
      [
        "category in",
        "filter[category.id][in]=#{category_one.id},#{category_two.id}",
        ids_at(3, 1, 0)
      ],
      [ "category isNull true", "filter[category.id][isNull]=true", ids_at(2) ],
      [ "category isNull false", "filter[category.id][isNull]=false", ids_at(3, 1, 0) ],
      [ "createdAt exact", "filter[createdAt]=#{encoded(second_time.iso8601)}", ids_at(1) ],
      [ "createdAt gt", "filter[createdAt][gt]=#{encoded(second_time.iso8601)}", ids_at(3, 2) ],
      [ "createdAt gte", "filter[createdAt][gte]=#{encoded(third_time.iso8601)}", ids_at(3, 2) ],
      [ "createdAt lt", "filter[createdAt][lt]=#{encoded(second_time.iso8601)}", ids_at(0) ],
      [ "createdAt lte", "filter[createdAt][lte]=#{encoded(second_time.iso8601)}", ids_at(1, 0) ]
    ]

    cases.each do |label, query, expected_ids|
      aggregate_failures(label) do
        expect(requested_ids(query)).to eq(expected_ids)
      end
    end
  end

  it "keeps SQL wildcard and injection-shaped filter values as literal data" do
    injected = create(:example, title: "x' OR 1=1 --", score: 50, created_at: first_time)

    expect(requested_ids("filter[title]=#{encoded(injected.title)}")).to eq([ injected.id.downcase ])
    expect(requested_ids("filter[title][contains]=#{encoded('%_')}")).to eq(ids_at(0))
  end

  it "accepts canonical category UUIDs without restricting UUID version bits" do
    category = create(:example_category, id: "00000000-0000-0000-0000-000000000000")
    example = create(:example, category: category, created_at: first_time)

    expect(requested_ids("filter[category.id]=#{category.id}")).to eq([ example.id.downcase ])
  end

  it "applies every allowlisted ascending and descending sort with a stable id tie-breaker" do
    cases = [
      [ "default", nil, ids_at(3, 2, 1, 0) ],
      [ "title", "sort=title", ids_at(0, 1, 2, 3) ],
      [ "-title", "sort=-title", ids_at(3, 2, 1, 0) ],
      [ "status", "sort=status", ids_at(1, 2, 3, 0) ],
      [ "-status", "sort=-status", ids_at(0, 3, 1, 2) ],
      [ "score", "sort=score", ids_at(0, 1, 2, 3) ],
      [ "-score", "sort=-score", ids_at(3, 2, 1, 0) ],
      [ "createdAt", "sort=createdAt", ids_at(0, 1, 2, 3) ],
      [ "-createdAt", "sort=-createdAt", ids_at(3, 2, 1, 0) ],
      [ "updatedAt", "sort=updatedAt", ids_at(3, 2, 1, 0) ],
      [ "-updatedAt", "sort=-updatedAt", ids_at(0, 1, 2, 3) ]
    ]

    cases.each do |label, query, expected_ids|
      aggregate_failures(label) do
        expect(requested_ids(query)).to eq(expected_ids)
      end
    end
  end

  it "uses ascending id as the default and user sort tie-breaker" do
    earlier_id = "00000000-0000-4000-8000-000000000000"
    create(
      :example,
      id: earlier_id,
      title: "Inserted after Delta",
      status: "active",
      score: 40,
      created_at: fourth_time
    )

    expect(requested_ids.first(2)).to eq([ earlier_id, ids_at(3).first ])
    expect(requested_ids("sort=status").first(3)).to eq([ earlier_id, *ids_at(1, 2) ])
  end

  it "loads allowlisted includes, removes duplicates, and emits an empty included array for include=" do
    category_identifiers = [
      [ "exampleCategories", category_one.id.downcase ],
      [ "exampleCategories", category_two.id.downcase ]
    ]
    tag_identifiers = [
      [ "exampleTags", tag_one.id.downcase ],
      [ "exampleTags", tag_two.id.downcase ]
    ]
    cases = [
      [ "category", category_identifiers ],
      [ "tags", tag_identifiers ],
      [ "category,tags,category,tags", category_identifiers + tag_identifiers ]
    ]

    cases.each do |include_value, expected_identifiers|
      aggregate_failures(include_value) do
        document = request_document("include=#{include_value}")
        identifiers = document.fetch("included").map { |resource| [ resource.fetch("type"), resource.fetch("id") ] }

        expect(identifiers).to contain_exactly(*expected_identifiers)
        expect(identifiers).to eq(identifiers.uniq)
      end
    end

    expect(request_document).not_to have_key("included")
    expect(request_document("include=").fetch("included")).to eq([])
  end

  it "uses default and maximum page sizes with totalCount and boundary links" do
    create_list(:example, 97)

    first_page = request_document
    expect(first_page.fetch("data").size).to eq(20)
    expect(first_page.fetch("meta")).to eq("totalCount" => 101)
    expect(first_page.fetch("links").keys).to eq(%w[self first prev next last])
    expect(first_page.dig("links", "prev")).to be_nil
    expect(decoded_link_query(first_page.dig("links", "self"))).to include(
      "page[number]" => "1",
      "page[size]" => "20"
    )
    expect(decoded_link_query(first_page.dig("links", "last"))).to include("page[number]" => "6")

    maximum_page = request_document("page[size]=200")
    expect(maximum_page.fetch("data").size).to eq(100)
    expect(maximum_page.fetch("meta")).to eq("totalCount" => 101)
    expect(decoded_link_query(maximum_page.dig("links", "self"))).to include("page[size]" => "100")

    last_page = request_document("page[number]=2&page[size]=100")
    expect(last_page.fetch("data").size).to eq(1)
    expect(last_page.dig("links", "next")).to be_nil
    expect(decoded_link_query(last_page.dig("links", "prev"))).to include("page[number]" => "1")
  end

  it "preserves non-page query parameters in every pagination link and uses null boundaries" do
    query = "filter[status][in]=draft,active&sort=title&include=category&page[number]=2&page[size]=1"
    document = request_document(query)
    links = document.fetch("links")
    expected_pages = { "self" => "2", "first" => "1", "prev" => "1", "next" => "3", "last" => "3" }

    expect(document.fetch("meta")).to eq("totalCount" => 3)
    expect(links.keys).to eq(%w[self first prev next last])
    expected_pages.each do |name, page_number|
      aggregate_failures(name) do
        expect(links.fetch(name)).to start_with("#{PROBE_PATH}?")
        expect(decoded_link_query(links.fetch(name))).to include(
          "filter[status][in]" => "draft,active",
          "sort" => "title",
          "include" => "category",
          "page[number]" => page_number,
          "page[size]" => "1"
        )
      end
    end

    first_page = request_document("page[number]=1&page[size]=4")
    expect(first_page.dig("links", "prev")).to be_nil
    expect(first_page.dig("links", "next")).to be_nil
  end

  it "returns the exact error family for unknown names, operators, and invalid typed values" do
    cases = [
      [ "filter[missing]=value", "INVALID_FILTER", "filter[missing]" ],
      [ "filter[score][contains]=20", "INVALID_FILTER", "filter[score][contains]" ],
      [ "filter[score]=not-a-number", "INVALID_FILTER", "filter[score]" ],
      [ "filter[status]=missing", "INVALID_FILTER", "filter[status]" ],
      [ "filter[category.id]=not-a-uuid", "INVALID_FILTER", "filter[category.id]" ],
      [ "filter[createdAt]=2026-07-15T12:00:00", "INVALID_FILTER", "filter[createdAt]" ],
      [ "filter[category.id][isNull]=TRUE", "INVALID_FILTER", "filter[category.id][isNull]" ],
      [ "sort=id", "INVALID_SORT", "sort" ],
      [ "include=missing", "INVALID_INCLUDE", "include" ],
      [ "page[cursor]=value", "INVALID_PAGE", "page[cursor]" ],
      [ "page[number]=0", "INVALID_PAGE", "page[number]" ],
      [ "page[size]=1.5", "INVALID_PAGE", "page[size]" ],
      [ "fields[examples]=title", "INVALID_QUERY_PARAMETER", "fields[examples]" ]
    ]

    cases.each do |query, code, parameter|
      aggregate_failures(query) do
        expect_query_error(query, code: code, parameter: parameter)
      end
    end
  end

  it "detects raw duplicate single parameters before Rails collapses them" do
    cases = [
      [ "filter[score]=10&filter[score]=20", "INVALID_FILTER", "filter[score]" ],
      [ "sort=title&sort=score", "INVALID_SORT", "sort" ],
      [ "include=category&include=tags", "INVALID_INCLUDE", "include" ],
      [ "page[number]=1&page[number]=2", "INVALID_PAGE", "page[number]" ],
      [
        "fields[examples]=title&fields[examples]=score",
        "INVALID_QUERY_PARAMETER",
        "fields[examples]"
      ]
    ]

    cases.each do |query, code, parameter|
      aggregate_failures(query) do
        expect_query_error(query, code: code, parameter: parameter)
      end
    end
  end

  it "maps scalar and nested filter shape conflicts in both query orders" do
    cases = [
      [ "filter[score]=10&filter[score][exact]=20", "filter[score][exact]" ],
      [ "filter[score][exact]=20&filter[score]=10", "filter[score]" ],
      [ "filter[score]=10&filter[score][gt]=20", "filter[score][gt]" ],
      [ "filter[score][gt]=20&filter[score]=10", "filter[score]" ]
    ]

    cases.each do |query, parameter|
      aggregate_failures(query) do
        expect_query_error(query, code: "INVALID_FILTER", parameter: parameter)
      end
    end
  end

  it "maps scalar and nested sort and page shape conflicts in both query orders" do
    cases = [
      [ "sort=score&sort[field]=title", "INVALID_SORT", "sort[field]" ],
      [ "sort[field]=title&sort=score", "INVALID_SORT", "sort" ],
      [ "page[number]=1&page[number][extra]=2", "INVALID_PAGE", "page[number][extra]" ],
      [ "page[number][extra]=2&page[number]=1", "INVALID_PAGE", "page[number]" ]
    ]

    cases.each do |query, code, parameter|
      aggregate_failures(query) do
        expect_query_error(query, code: code, parameter: parameter)
      end
    end
  end

  it "does not install strict query error conversion on a legacy index controller" do
    get LEGACY_PROBE_PATH, headers: jsonapi_headers

    expect(response).to have_http_status(:ok)
    expect(parsed_body.fetch("data").pluck("id")).to contain_exactly(*ids_at(0, 1, 2, 3))

    get "#{LEGACY_PROBE_PATH}?sort=score&sort[field]=title", headers: jsonapi_headers

    expect(response).to have_http_status(:bad_request)
    expect(response.headers.fetch("Content-Type")).not_to eq(JsonapiRequestHelper::JSONAPI_MEDIA_TYPE)
    expect(response.body).not_to include("INVALID_SORT")
  end

  it "does not swallow an unrelated BadRequest on a strict query controller" do
    get "#{PROBE_PATH}?unknown=value&unknown[field]=nested", headers: jsonapi_headers

    expect(response).to have_http_status(:bad_request)
    expect(response.headers.fetch("Content-Type")).not_to eq(JsonapiRequestHelper::JSONAPI_MEDIA_TYPE)
    expect(response.body).not_to include("INVALID_QUERY_PARAMETER")
  end
end
