# frozen_string_literal: true

require "rails_helper"

RSpec.describe "Example CRUD", type: :request do
  let(:collection_path) { "/api/v1/examples" }

  before { mock_authenticated_user }

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
      headers: jsonapi_headers(cookie: "valid-session")
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
