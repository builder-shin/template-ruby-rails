# frozen_string_literal: true

require "rails_helper"
require "uri"

RSpec.describe "Example relationships", type: :request do
  let(:collection_path) { "/api/v1/examples" }

  before { mock_bearer_user }

  def relationship_path(example, name)
    "#{collection_path}/#{example.id}/relationships/#{name}"
  end

  def related_path(example, name)
    "#{collection_path}/#{example.id}/#{name}"
  end

  def identifier(type, record_or_id)
    { type: type, id: record_or_id.respond_to?(:id) ? record_or_id.id : record_or_id }
  end

  def mutate(method, path, data)
    public_send(
      method,
      path,
      params: { data: data }.to_json,
      headers: jsonapi_headers.merge(auth_bearer_headers)
    )
  end

  def expect_error(status, code, pointer: nil)
    expect(response).to have_http_status(status)
    error = parsed_body.fetch("errors").first
    expect(error).to include("status" => Rack::Utils.status_code(status).to_s, "code" => code)
    expect(error["source"]).to eq("pointer" => pointer) if pointer
  end

  def decoded_link_query(link)
    URI.decode_www_form(URI.parse(link).query).to_h
  end

  # 응답 문서에서 태그 순서가 세 자리 모두 태그 id 오름차순이다 -
  # data.relationships, included, 그리고 관련 자원 라우트.
  #
  # 모델 스펙(spec/models/example_relationships_spec.rb)이 연관 자체의 순서를
  # 지키고, 여기는 **문서로 나가는 순서**를 지킨다. 직렬화기가 정렬을 다시
  # 잃어버릴 수 있는 자리라 따로 잰다.
  #
  # 픽스처의 id 순서와 이름 순서를 일부러 뒤집는다 - 둘이 같으면 정렬 키를
  # 바꿔치기한 뮤턴트가 안 죽는다.
  describe "태그 순서" do
    let!(:first_by_id) do
      create(:example_tag, id: "44440000-0000-4000-8000-000000000001", name: "probe-order 003 alpha")
    end
    let!(:second_by_id) do
      create(:example_tag, id: "44440000-0000-4000-8000-000000000002", name: "probe-order 001 bravo")
    end

    let(:expected_ids) { [ first_by_id.id, second_by_id.id ] }

    # 붙이는 순서를 id 순서의 **역**으로 준다. 백엔드가 붙인 순서를 그대로
    # 되돌리면 여기서 죽는다.
    def create_example_with_reversed_tags
      post(
        collection_path,
        params: {
          data: {
            type: "examples",
            attributes: { title: "probe-order 문서", status: "draft", score: 0 },
            relationships: {
              tags: { data: [ identifier("exampleTags", second_by_id), identifier("exampleTags", first_by_id) ] }
            }
          }
        }.to_json,
        headers: jsonapi_headers.merge(auth_bearer_headers)
      )
      expect(response).to have_http_status(:created)
      parsed_body.dig("data", "id")
    end

    it "상세 문서의 relationships 와 included 가 모두 id 오름차순이다" do
      id = create_example_with_reversed_tags

      get "#{collection_path}/#{id}?include=tags", headers: jsonapi_headers

      expect(response).to have_http_status(:ok)
      expect(parsed_body.dig("data", "relationships", "tags", "data").pluck("id")).to eq(expected_ids)
      included_tags = parsed_body.fetch("included").select { |resource| resource["type"] == "exampleTags" }
      expect(included_tags.pluck("id")).to eq(expected_ids)
    end

    it "목록 문서도 같은 순서를 낸다" do
      create_example_with_reversed_tags

      get "#{collection_path}?include=tags", headers: jsonapi_headers

      expect(response).to have_http_status(:ok)
      tagged = parsed_body.fetch("data").find { |resource| resource.dig("relationships", "tags", "data").present? }
      expect(tagged.dig("relationships", "tags", "data").pluck("id")).to eq(expected_ids)
    end

    it "관계 라우트와 관련 자원 라우트도 같은 순서를 낸다" do
      id = create_example_with_reversed_tags
      example = Example.find(id)

      get relationship_path(example, "tags"), headers: jsonapi_headers
      expect(parsed_body.fetch("data").pluck("id")).to eq(expected_ids)

      get related_path(example, "tags"), headers: jsonapi_headers
      expect(parsed_body.fetch("data").pluck("id")).to eq(expected_ids)
    end
  end

  it "replaces, reads, and clears the category relationship" do
    example = create(:example)
    category = create(:example_category, name: "분류")
    path = relationship_path(example, "category")

    mutate(:patch, path, identifier("exampleCategories", category))

    expect(response).to have_http_status(:no_content)
    expect(response.body).to be_empty

    get path, headers: jsonapi_headers

    expect(response).to have_http_status(:ok)
    expect(parsed_body).to eq(
      "data" => { "type" => "exampleCategories", "id" => category.id },
      "links" => { "self" => path, "related" => related_path(example, "category") }
    )

    get related_path(example, "category"), headers: jsonapi_headers

    expect(response).to have_http_status(:ok)
    expect(parsed_body.fetch("data")).to include(
      "type" => "exampleCategories",
      "id" => category.id,
      "attributes" => { "name" => "분류" }
    )

    mutate(:patch, path, nil)

    expect(response).to have_http_status(:no_content)
    expect(example.reload.category).to be_nil
  end

  it "returns null category linkage" do
    example = create(:example)
    path = relationship_path(example, "category")

    get path, headers: jsonapi_headers

    expect(response).to have_http_status(:ok)
    expect(parsed_body).to eq(
      "data" => nil,
      "links" => { "self" => path, "related" => related_path(example, "category") }
    )
  end

  it "rejects a category linkage with the wrong type" do
    example = create(:example)

    mutate(
      :patch,
      relationship_path(example, "category"),
      identifier("exampleTags", SecureRandom.uuid)
    )

    expect_error(:conflict, "TYPE_MISMATCH", pointer: "/data/type")
    expect(example.reload.category).to be_nil
  end

  it "reports missing and malformed category ids as missing relationship resources" do
    example = create(:example)
    path = relationship_path(example, "category")

    [ SecureRandom.uuid, "not-a-uuid" ].each do |missing_id|
      mutate(:patch, path, identifier("exampleCategories", missing_id))

      expect_error(
        :not_found,
        "RELATIONSHIP_RESOURCE_NOT_FOUND",
        pointer: "/data/id"
      )
    end
    expect(example.reload.category).to be_nil
  end

  it "adds, replaces, removes, and reads tag relationships" do
    example = create(:example)
    first, second, third = create_list(:example_tag, 3)
    path = relationship_path(example, "tags")

    mutate(
      :post,
      path,
      [ identifier("exampleTags", first), identifier("exampleTags", second) ]
    )
    expect(response).to have_http_status(:no_content)
    expect(response.body).to be_empty

    mutate(
      :patch,
      path,
      [ identifier("exampleTags", second), identifier("exampleTags", third) ]
    )
    expect(response).to have_http_status(:no_content)

    mutate(:delete, path, [ identifier("exampleTags", second) ])
    expect(response).to have_http_status(:no_content)

    get path, headers: jsonapi_headers

    expect(response).to have_http_status(:ok)
    expect(parsed_body).to eq(
      "data" => [ { "type" => "exampleTags", "id" => third.id } ],
      "links" => { "self" => path, "related" => related_path(example, "tags") }
    )

    get related_path(example, "tags"), headers: jsonapi_headers

    expect(response).to have_http_status(:ok)
    expect(parsed_body.fetch("data")).to contain_exactly(
      include(
        "type" => "exampleTags",
        "id" => third.id,
        "attributes" => { "name" => third.name }
      )
    )
    expect(example.reload.tag_ids).to eq([ third.id ])
  end

  it "always emits totalCount and a non-null last link for the tags related collection" do
    # 정본(FastAPI/NestJS)과 맞춰 이 라우트는 page[totals]를 요청받지 않아도 항상
    # 센다 — meta도 links.last도 조건부가 아니다.
    example = create(:example)
    create_list(:example_tag, 3).each { |tag| create(:example_tagging, example: example, example_tag: tag) }

    get related_path(example, "tags"), headers: jsonapi_headers

    expect(response).to have_http_status(:ok)
    document = parsed_body
    expect(document.fetch("meta")).to eq("totalCount" => 3)
    expect(document.fetch("links").keys).to eq(%w[self first prev next last])
    expect(document.dig("links", "prev")).to be_nil
    expect(document.dig("links", "next")).to be_nil
    expect(document.dig("links", "last")).not_to be_nil
  end

  it "clamps page[size] beyond the maximum to one hundred on the tags related collection" do
    example = create(:example)

    get "#{related_path(example, 'tags')}?page[size]=200", headers: jsonapi_headers

    expect(response).to have_http_status(:ok)
    expect(decoded_link_query(parsed_body.dig("links", "self"))).to include("page[size]" => "100")
  end

  it "walks the tags related collection by following links.next and matches a page[size]=100 baseline" do
    example = create(:example)
    create_list(:example_tag, 5).each { |tag| create(:example_tagging, example: example, example_tag: tag) }

    seen = []
    url = "#{related_path(example, 'tags')}?page[size]=2"
    while url
      get url, headers: jsonapi_headers
      expect(response).to have_http_status(:ok)
      document = parsed_body
      seen.concat(document.fetch("data").map { |resource| resource.fetch("id") })
      url = document.fetch("links").fetch("next")
    end

    get "#{related_path(example, 'tags')}?page[size]=100", headers: jsonapi_headers
    expected = parsed_body.fetch("data").map { |resource| resource.fetch("id") }
    expect(seen).to eq(expected)
    expect(seen.length).to eq(5)
    # id 오름차순이라고 명시적으로 고정한다. 태그 id는 무작위 UUID라 삽입 순서와
    # 무관하므로, 이 assertion 없이는 우연히 일치하는 물리적 정렬만으로도
    # order(:id) 누락을 눈치채지 못할 수 있다.
    expect(seen).to eq(seen.sort)
  end

  it "rejects a tag linkage with the wrong type" do
    example = create(:example)

    mutate(
      :post,
      relationship_path(example, "tags"),
      [ identifier("exampleCategories", SecureRandom.uuid) ]
    )

    expect_error(:conflict, "TYPE_MISMATCH", pointer: "/data/0/type")
    expect(example.reload.tags).to be_empty
  end

  it "rejects duplicate tag linkage with the second identifier pointer" do
    example = create(:example)
    tag = create(:example_tag)
    duplicate = identifier("exampleTags", tag)

    mutate(:post, relationship_path(example, "tags"), [ duplicate, duplicate ])

    expect_error(:bad_request, "INVALID_JSONAPI_DOCUMENT", pointer: "/data/1/id")
    expect(example.reload.tags).to be_empty
  end

  it "rolls back a complete tag replacement when a related resource is missing" do
    example = create(:example)
    existing = create(:example_tag)
    replacement = create(:example_tag)
    create(:example_tagging, example: example, example_tag: existing)

    mutate(
      :patch,
      relationship_path(example, "tags"),
      [ identifier("exampleTags", replacement), identifier("exampleTags", SecureRandom.uuid) ]
    )

    expect_error(
      :not_found,
      "RELATIONSHIP_RESOURCE_NOT_FOUND",
      pointer: "/data/1/id"
    )
    expect(example.reload.tag_ids).to eq([ existing.id ])
  end

  it "rolls back a tag addition when the relationship hook fails" do
    example = create(:example)
    tag = create(:example_tag)
    allow_any_instance_of(Api::V1::ExamplesController).to receive(:relationship_after_save)
      .and_raise(StandardError, "hook failure")

    mutate(:post, relationship_path(example, "tags"), [ identifier("exampleTags", tag) ])

    expect_error(:internal_server_error, "INTERNAL_SERVER_ERROR")
    expect(example.reload.tags).to be_empty
  end

  it "rolls back a tag addition when final serialization fails" do
    example = create(:example)
    tag = create(:example_tag)
    allow(ExampleSerializer).to receive(:new).and_raise(StandardError, "serializer failure")

    mutate(:post, relationship_path(example, "tags"), [ identifier("exampleTags", tag) ])

    expect_error(:internal_server_error, "INTERNAL_SERVER_ERROR")
    expect(example.reload.tags).to be_empty
  end

  it "returns RESOURCE_NOT_FOUND when the parent does not exist" do
    missing_id = SecureRandom.uuid

    get "#{collection_path}/#{missing_id}/relationships/tags", headers: jsonapi_headers

    expect_error(:not_found, "RESOURCE_NOT_FOUND")
  end
end
