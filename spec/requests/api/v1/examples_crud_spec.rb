# frozen_string_literal: true

require "rails_helper"

RSpec.describe "Example CRUD", type: :request do
  let(:collection_path) { "/api/v1/examples" }

  before { mock_bearer_user }

  def resource_path(example_or_id)
    "#{collection_path}/#{example_or_id.respond_to?(:id) ? example_or_id.id : example_or_id}"
  end

  def document(attributes: {}, relationships: nil, id: nil, type: "examples")
    data = { type: type, attributes: attributes }
    data[:id] = id if id
    data[:relationships] = relationships if relationships
    { data: data }
  end

  def perform_jsonapi(method, path, body = nil)
    public_send(
      method,
      path,
      params: body&.to_json,
      headers: jsonapi_headers.merge(auth_bearer_headers)
    )
  end

  def expect_error(status, code, pointer: nil)
    expect(response).to have_http_status(status)
    expect(response.headers.fetch("Content-Type")).to eq(JsonapiRequestHelper::JSONAPI_MEDIA_TYPE)
    error = parsed_body.fetch("errors").first
    expect(error).to include("status" => Rack::Utils.status_code(status).to_s, "code" => code)
    expect(error["source"]).to eq("pointer" => pointer) if pointer
  end

  it "returns the public index and show documents" do
    first = create(:example, title: "First")
    second = create(:example, title: "Second")

    get collection_path, headers: jsonapi_headers

    expect(response).to have_http_status(:ok)
    expect(parsed_body.fetch("data").pluck("id")).to contain_exactly(first.id, second.id)

    get resource_path(first), headers: jsonapi_headers

    expect(response).to have_http_status(:ok)
    expect(parsed_body.dig("data", "id")).to eq(first.id)
    expect(parsed_body.dig("data", "attributes", "title")).to eq("First")
  end

  it "does not emit a meta member on a single-resource show" do
    # 단건 조회에는 total-count 개념이 없다 — jsonapi_pagination_meta가 컬렉션이
    # 아닌 자원에는 {}를 돌려주므로, meta 자체를 없애지 않으면 `"total-count": null`이
    # 나간다(정본은 show에 meta를 전혀 싣지 않는다).
    example = create(:example)

    get resource_path(example), headers: jsonapi_headers

    expect(response).to have_http_status(:ok)
    expect(parsed_body).not_to have_key("meta")
  end

  it "creates an Example with relationships and a canonical Location" do
    category = create(:example_category)
    tags = create_list(:example_tag, 2)
    relationships = {
      category: { data: { type: "exampleCategories", id: category.id } },
      tags: { data: tags.map { |tag| { type: "exampleTags", id: tag.id } } }
    }

    perform_jsonapi(
      :post,
      collection_path,
      document(
        attributes: { title: "Created", description: "Body", status: "active", score: 73 },
        relationships: relationships
      )
    )

    expect(response).to have_http_status(:created)
    resource = parsed_body.fetch("data")
    expect(response.headers.fetch("Location")).to eq(resource.dig("links", "self"))
    expect(response.headers.fetch("Content-Type")).to eq(JsonapiRequestHelper::JSONAPI_MEDIA_TYPE)

    persisted = Example.find(resource.fetch("id"))
    expect(persisted.attributes.slice("title", "description", "status", "score")).to eq(
      "title" => "Created",
      "description" => "Body",
      "status" => "active",
      "score" => 73
    )
    expect(persisted.category_id).to eq(category.id)
    expect(persisted.tag_ids).to contain_exactly(*tags.map(&:id))
  end

  # 쓰기 경로(CrudActions#render_jsonapi_payload → JSON.generate)와 읽기 경로
  # (render jsonapi: → ActiveSupport 인코더)가 같은 자원의 같은 필드를 서로 다른
  # 형식으로 내던 결함의 가드. 실측(고치기 전): POST가
  # "2026-09-05 23:59:49 +0900"(Time#to_s — Time.iso8601이 ArgumentError를 낸다),
  # GET이 "2026-09-05T23:59:49.418+09:00". `Time.iso8601` 파싱 성공만 단언하면
  # 밀리초 정밀도 차이를 못 잡으므로 **문자열이 정확히 같은지**를 본다.
  it "renders createdAt/updatedAt on the write path exactly as the read path does" do
    perform_jsonapi(:post, collection_path, document(attributes: { title: "Timestamps" }))

    expect(response).to have_http_status(:created)
    written = parsed_body.dig("data", "attributes")
    id = parsed_body.dig("data", "id")

    get resource_path(id), headers: jsonapi_headers

    expect(response).to have_http_status(:ok)
    read = parsed_body.dig("data", "attributes")
    aggregate_failures do
      expect(written.fetch("createdAt")).to eq(read.fetch("createdAt"))
      expect(written.fetch("updatedAt")).to eq(read.fetch("updatedAt"))
      expect { Time.iso8601(written.fetch("createdAt")) }.not_to raise_error
    end
  end

  # 선언 밖 enum 값은 500 이 아니라 422 다.
  #
  # 고치기 전: 모델의 enum 대입이 ArgumentError 를 냈고 그것이
  # rescue_from StandardError 에 걸려 500 이 됐다. 클라이언트는 어느 입력 아래에
  # 오류를 붙일지 알 수 없었고, 사용자 입력 오류가 서버 오류율로 잡혔다.
  #
  # 프로브 값은 실전 어휘(draft·active·archived)와 겹치지 않게 고정한다.
  describe "선언 밖 enum 값" do
    let(:undeclared_status) { "probe-lab-undeclared" }

    it "생성에서 422 와 status 포인터를 낸다" do
      perform_jsonapi(
        :post,
        collection_path,
        document(attributes: { title: "probe-lab enum", status: undeclared_status, score: 0 })
      )

      expect_error(:unprocessable_content, "VALIDATION_ERROR", pointer: "/data/attributes/status")
    end

    it "수정에서 422 와 status 포인터를 낸다" do
      example = create(:example, status: "draft")

      perform_jsonapi(
        :patch,
        resource_path(example),
        document(attributes: { status: undeclared_status }, id: example.id)
      )

      expect_error(:unprocessable_content, "VALIDATION_ERROR", pointer: "/data/attributes/status")
    end

    it "교체(PUT)에서 422 와 status 포인터를 낸다" do
      example = create(:example, status: "draft")

      perform_jsonapi(
        :put,
        resource_path(example),
        document(attributes: { title: "probe-lab enum", status: undeclared_status, score: 0 }, id: example.id)
      )

      expect_error(:unprocessable_content, "VALIDATION_ERROR", pointer: "/data/attributes/status")
    end

    # 422 로 바뀌어도 "행이 만들어지지 않는다" 는 명제는 그대로여야 한다 -
    # 거부의 모양만 고친 것이지 거부 자체를 무르는 변경이 아니다.
    it "행을 만들지 않고 기존 값도 바꾸지 않는다" do
      example = create(:example, status: "draft")

      expect {
        perform_jsonapi(
          :post,
          collection_path,
          document(attributes: { title: "probe-lab enum", status: undeclared_status, score: 0 })
        )
      }.not_to change(Example, :count)

      perform_jsonapi(
        :patch,
        resource_path(example),
        document(attributes: { status: undeclared_status }, id: example.id)
      )

      expect(example.reload.status).to eq("draft")
    end
  end

  it "rejects unknown attributes instead of silently discarding them" do
    perform_jsonapi(
      :post,
      collection_path,
      document(attributes: { title: "Known", privateField: "secret" })
    )

    expect_error(
      :bad_request,
      "INVALID_JSONAPI_DOCUMENT",
      pointer: "/data/attributes/privateField"
    )
    expect(Example.count).to eq(0)
  end

  it "validates embedded relationship object and linkage shapes before persistence" do
    cases = [
      [ { category: "not-an-object" }, "/data/relationships/category" ],
      [ { category: { data: [] } }, "/data/relationships/category/data" ],
      [ { tags: { data: {} } }, "/data/relationships/tags/data" ],
      [ { tags: { data: [ "not-an-identifier" ] } }, "/data/relationships/tags/data/0" ],
      [
        { tags: { data: [ { type: "exampleTags", id: SecureRandom.uuid, extra: true } ] } },
        "/data/relationships/tags/data/0/extra"
      ]
    ]

    cases.each do |relationships, pointer|
      aggregate_failures(pointer) do
        perform_jsonapi(
          :post,
          collection_path,
          document(attributes: { title: "Rejected" }, relationships: relationships)
        )

        expect_error(:bad_request, "INVALID_JSONAPI_DOCUMENT", pointer: pointer)
      end
    end
    expect(Example.count).to eq(0)
  end

  it "maps embedded relationship type, id, existence, and duplicate failures exactly" do
    tag = create(:example_tag)
    cases = [
      [
        { category: { data: { type: "exampleTags", id: tag.id } } },
        :conflict,
        "TYPE_MISMATCH",
        "/data/relationships/category/data/type"
      ],
      [
        { category: { data: { type: "exampleCategories", id: "not-a-uuid" } } },
        :not_found,
        "RELATIONSHIP_RESOURCE_NOT_FOUND",
        "/data/relationships/category/data/id"
      ],
      [
        { category: { data: { type: "exampleCategories", id: SecureRandom.uuid } } },
        :not_found,
        "RELATIONSHIP_RESOURCE_NOT_FOUND",
        "/data/relationships/category/data/id"
      ],
      [
        {
          tags: {
            data: [
              { type: "exampleTags", id: tag.id },
              { type: "exampleTags", id: tag.id }
            ]
          }
        },
        :bad_request,
        "INVALID_JSONAPI_DOCUMENT",
        "/data/relationships/tags/data/1/id"
      ]
    ]

    cases.each do |relationships, status, code, pointer|
      aggregate_failures(pointer) do
        perform_jsonapi(
          :post,
          collection_path,
          document(attributes: { title: "Rejected" }, relationships: relationships)
        )

        expect_error(status, code, pointer: pointer)
      end
    end
    expect(Example.count).to eq(0)
  end

  it "rolls back PATCH attributes when an embedded relationship resource is missing" do
    example = create(:example, title: "Before")
    relationships = {
      category: { data: { type: "exampleCategories", id: SecureRandom.uuid } }
    }

    perform_jsonapi(
      :patch,
      resource_path(example),
      document(attributes: { title: "After" }, relationships: relationships, id: example.id)
    )

    expect_error(
      :not_found,
      "RELATIONSHIP_RESOURCE_NOT_FOUND",
      pointer: "/data/relationships/category/data/id"
    )
    expect(example.reload.title).to eq("Before")
  end

  it "partially updates attributes without replacing relationships" do
    example = create(:example, :with_category, :with_tags, title: "Before", description: "Keep")
    category_id = example.category_id
    tag_ids = example.tag_ids

    perform_jsonapi(
      :patch,
      resource_path(example),
      document(attributes: { title: "After" }, id: example.id)
    )

    expect(response).to have_http_status(:ok)
    expect(parsed_body.dig("data", "attributes")).to include(
      "title" => "After",
      "description" => "Keep"
    )
    example.reload
    expect(example.category_id).to eq(category_id)
    expect(example.tag_ids).to contain_exactly(*tag_ids)
  end

  it "accepts a relationships-only PATCH" do
    old_category = create(:example_category)
    new_category = create(:example_category)
    old_tag = create(:example_tag)
    new_tags = create_list(:example_tag, 2)
    example = create(:example, title: "Unchanged", category: old_category)
    create(:example_tagging, example: example, example_tag: old_tag)

    relationships = {
      category: { data: { type: "exampleCategories", id: new_category.id } },
      tags: { data: new_tags.map { |tag| { type: "exampleTags", id: tag.id } } }
    }
    body = { data: { type: "examples", id: example.id, relationships: relationships } }

    perform_jsonapi(:patch, resource_path(example), body)

    expect(response).to have_http_status(:ok)
    expect(parsed_body.dig("data", "attributes", "title")).to eq("Unchanged")
    example.reload
    expect(example.category_id).to eq(new_category.id)
    expect(example.tag_ids).to contain_exactly(*new_tags.map(&:id))
  end

  it "deletes an Example with an empty 204 response" do
    example = create(:example)

    perform_jsonapi(:delete, resource_path(example))

    expect(response).to have_http_status(:no_content)
    expect(response.body).to be_empty
    expect(Example.exists?(example.id)).to be(false)
  end

  it "rolls back DELETE when the after hook fails" do
    example = create(:example)
    tag = create(:example_tag)
    tagging = create(:example_tagging, example: example, example_tag: tag)
    allow_any_instance_of(Api::V1::ExamplesController).to receive(:destroy_after_save)
      .and_raise(StandardError, "hook failure")

    perform_jsonapi(:delete, resource_path(example))

    expect_error(:internal_server_error, "INTERNAL_SERVER_ERROR")
    expect(Example.exists?(example.id)).to be(true)
    expect(ExampleTagging.exists?(tagging.attributes.slice("example_id", "example_tag_id"))).to be(true)
    expect(example.reload.tag_ids).to eq([ tag.id ])
  end

  it "rejects a non-resource data member" do
    perform_jsonapi(:post, collection_path, { data: [] })

    expect_error(:bad_request, "INVALID_JSONAPI_DOCUMENT")
  end

  it "rejects a mismatched resource type" do
    perform_jsonapi(
      :post,
      collection_path,
      document(attributes: { title: "Wrong", status: "draft", score: 0 }, type: "wrongExamples")
    )

    expect_error(:conflict, "TYPE_MISMATCH", pointer: "/data/type")
    expect(Example.count).to eq(0)
  end

  it "rejects a PATCH body id that differs from the URL id" do
    example = create(:example, title: "Before")

    perform_jsonapi(
      :patch,
      resource_path(example),
      document(attributes: { title: "After" }, id: SecureRandom.uuid)
    )

    expect_error(:conflict, "ID_MISMATCH", pointer: "/data/id")
    expect(example.reload.title).to eq("Before")
  end

  it "validates the PATCH document before looking up the resource" do
    resource_id = SecureRandom.uuid

    perform_jsonapi(
      :patch,
      resource_path(resource_id),
      document(attributes: { title: "After" }, id: resource_id, type: "wrongExamples")
    )

    expect_error(:conflict, "TYPE_MISMATCH", pointer: "/data/type")
  end

  it "rejects a PATCH body without an id" do
    example = create(:example, title: "Before")

    perform_jsonapi(
      :patch,
      resource_path(example),
      document(attributes: { title: "After" })
    )

    expect_error(:conflict, "ID_MISMATCH", pointer: "/data/id")
    expect(example.reload.title).to eq("Before")
  end

  it "rejects a client-generated POST id" do
    perform_jsonapi(
      :post,
      collection_path,
      document(attributes: { title: "Client ID", status: "draft", score: 0 }, id: SecureRandom.uuid)
    )

    expect_error(:forbidden, "CLIENT_GENERATED_ID_UNSUPPORTED", pointer: "/data/id")
    expect(Example.count).to eq(0)
  end

  it "rejects relationships outside the controller allowlist" do
    example = create(:example, title: "Before")
    body = {
      data: {
        type: "examples",
        id: example.id,
        relationships: { owner: { data: nil } }
      }
    }

    perform_jsonapi(:patch, resource_path(example), body)

    expect_error(
      :bad_request,
      "INVALID_JSONAPI_DOCUMENT",
      pointer: "/data/relationships/owner"
    )
  end

  it "maps a unique write race to RESOURCE_CONFLICT" do
    allow_any_instance_of(Api::V1::ExamplesController).to receive(:create_after_init)
      .and_raise(ActiveRecord::RecordNotUnique)

    perform_jsonapi(
      :post,
      collection_path,
      document(attributes: { title: "Race", status: "draft", score: 0 })
    )

    expect_error(:conflict, "RESOURCE_CONFLICT")
    expect(Example.count).to eq(0)
  end

  it "returns RESOURCE_NOT_FOUND for missing resources" do
    get resource_path(SecureRandom.uuid), headers: jsonapi_headers

    expect_error(:not_found, "RESOURCE_NOT_FOUND")
  end
end
