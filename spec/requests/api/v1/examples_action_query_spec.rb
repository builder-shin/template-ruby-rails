# frozen_string_literal: true

require "rails_helper"

RSpec.describe "Example action query allowlists", type: :request do
  let(:collection_path) { "/api/v1/examples" }

  before { mock_bearer_user }

  def resource_path(example)
    "#{collection_path}/#{example.id}"
  end

  def relationship_path(example, name)
    "#{resource_path(example)}/relationships/#{name}"
  end

  def resource_document(example: nil, title: "Changed")
    data = { type: "examples", attributes: { title: title } }
    data[:id] = example.id if example
    { data: data }
  end

  def relationship_document(data)
    { data: data }
  end

  def expect_query_error(code, parameter)
    expect(response).to have_http_status(:bad_request)
    expect(response.headers.fetch("Content-Type")).to eq(JsonapiRequestHelper::JSONAPI_MEDIA_TYPE)
    expect(parsed_body.fetch("errors").first).to include(
      "status" => "400",
      "code" => code,
      "source" => { "parameter" => parameter }
    )
  end

  it "allows include on show while rejecting collection-only and sparse-field queries" do
    category = create(:example_category)
    example = create(:example, category: category)
    cases = [
      [ "filter[title]=ignored", "INVALID_FILTER", "filter[title]" ],
      [ "sort=title", "INVALID_SORT", "sort" ],
      [ "page[number]=1", "INVALID_PAGE", "page[number]" ],
      [ "fields[examples]=title", "INVALID_QUERY_PARAMETER", "fields[examples]" ]
    ]

    cases.each do |query, code, parameter|
      aggregate_failures(query) do
        get "#{resource_path(example)}?#{query}", headers: jsonapi_headers

        expect_query_error(code, parameter)
      end
    end

    get "#{resource_path(example)}?include=category", headers: jsonapi_headers

    expect(response).to have_http_status(:ok)
    expect(parsed_body.fetch("included").first).to include(
      "type" => "exampleCategories",
      "id" => category.id
    )
  end

  it "maps a raw query shape collision on the real Example index" do
    get "#{collection_path}?unknown=value&unknown[field]=nested", headers: jsonapi_headers

    expect_query_error("INVALID_QUERY_PARAMETER", "unknown[field]")
    expect(response.body).not_to include("ActionController::BadRequest", "Conflicting types")
  end

  it "rejects every resource write query before mutating database state" do
    patched = create(:example, title: "Patch before")
    replaced = create(:example, title: "Put before", status: "active", score: 80)
    destroyed = create(:example, title: "Delete before")
    requests = [
      [ :post, collection_path, resource_document ],
      [ :patch, resource_path(patched), resource_document(example: patched) ],
      [ :put, resource_path(replaced), resource_document(example: replaced) ],
      [ :delete, resource_path(destroyed), nil ]
    ]

    requests.each do |method, path, body|
      aggregate_failures(method) do
        public_send(
          method,
          "#{path}?fields[examples]=title",
          params: body&.to_json,
          headers: jsonapi_headers.merge(auth_bearer_headers)
        )

        expect_query_error("INVALID_QUERY_PARAMETER", "fields[examples]")
      end
    end

    expect(Example.count).to eq(3)
    expect(patched.reload.title).to eq("Patch before")
    expect(replaced.reload).to have_attributes(title: "Put before", status: "active", score: 80)
    expect(Example.exists?(destroyed.id)).to be(true)
  end

  it "rejects relationship and related-resource queries before relationship mutation" do
    original_category = create(:example_category)
    replacement_category = create(:example_category)
    original_tag = create(:example_tag)
    replacement_tag = create(:example_tag)
    example = create(:example, category: original_category)
    create(:example_tagging, example: example, example_tag: original_tag)
    identifier = ->(type, record) { { type: type, id: record.id } }
    tag_document = relationship_document([ identifier.call("exampleTags", replacement_tag) ])
    requests = [
      [ :get, relationship_path(example, "category"), nil ],
      [ :get, "#{resource_path(example)}/category", nil ],
      [ :get, relationship_path(example, "tags"), nil ],
      [ :get, "#{resource_path(example)}/tags", nil ],
      [
        :patch,
        relationship_path(example, "category"),
        relationship_document(identifier.call("exampleCategories", replacement_category))
      ],
      [ :post, relationship_path(example, "tags"), tag_document ],
      [ :patch, relationship_path(example, "tags"), tag_document ],
      [
        :delete,
        relationship_path(example, "tags"),
        relationship_document([ identifier.call("exampleTags", original_tag) ])
      ]
    ]

    requests.each do |method, path, body|
      aggregate_failures("#{method} #{path}") do
        public_send(
          method,
          "#{path}?fields[examples]=title",
          params: body&.to_json,
          headers: jsonapi_headers.merge(auth_bearer_headers)
        )

        expect_query_error("INVALID_QUERY_PARAMETER", "fields[examples]")
      end
    end

    example.reload
    expect(example.category_id).to eq(original_category.id)
    expect(example.tag_ids).to eq([ original_tag.id ])
  end

  it "allows only page[number]/page[size] on the tags related collection" do
    example = create(:example)

    cases = [
      [ "filter[name]=tag", "INVALID_FILTER", "filter[name]" ],
      [ "sort=name", "INVALID_SORT", "sort" ],
      [ "include=tags", "INVALID_INCLUDE", "include" ],
      # 값 자체는 정수로도 파싱될 값을 쓴다 — page[after]/page[totals]가 허용 목록에
      # 잘못 끼어들면 각각 page[number]/page[size]로 오인되어 200이 나가 버린다.
      # 빈 문자열이나 "true"를 쓰면 정수 파싱 실패로도 우연히 같은 INVALID_PAGE가
      # 나서 허용 목록 자체가 깨져도 테스트가 눈치채지 못한다.
      [ "page[after]=5", "INVALID_PAGE", "page[after]" ],
      [ "page[totals]=1", "INVALID_PAGE", "page[totals]" ],
      [ "page[number]=1&page[number]=2", "INVALID_PAGE", "page[number]" ],
      [ "bogus=1", "INVALID_QUERY_PARAMETER", "bogus" ]
    ]

    cases.each do |query, code, parameter|
      aggregate_failures(query) do
        get "#{resource_path(example)}/tags?#{query}", headers: jsonapi_headers

        expect_query_error(code, parameter)
      end
    end
  end
end
