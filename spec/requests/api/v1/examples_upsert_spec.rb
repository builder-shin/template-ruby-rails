# frozen_string_literal: true

require "rails_helper"
require "database_cleaner/active_record"

RSpec.describe "Example atomic PUT upsert", type: :request do
  let(:collection_path) { "/api/v1/examples" }

  before { mock_bearer_user }

  def resource_path(id)
    "#{collection_path}/#{id}"
  end

  def put_document(id:, title:, description: :omitted, status: "draft", score: 0, relationships: nil)
    attributes = { title: title, status: status, score: score }
    attributes[:description] = description unless description == :omitted
    data = { type: "examples", id: id, attributes: attributes }
    data[:relationships] = relationships if relationships
    { data: data }
  end

  def perform_put(id, body)
    put resource_path(id), params: body.to_json, headers: jsonapi_headers.merge(auth_bearer_headers)
  end

  it "creates a missing UUID with 201 and the requested id" do
    resource_id = SecureRandom.uuid

    perform_put(resource_id, put_document(id: resource_id, title: "Created", score: 17))

    expect(response).to have_http_status(:created)
    resource = parsed_body.fetch("data")
    expect(resource.fetch("id")).to eq(resource_id)
    expect(response.headers.fetch("Location")).to eq(resource.dig("links", "self"))
    expect(Example.find(resource_id).title).to eq("Created")
  end

  it "fully replaces an existing resource and resets omitted nullable relationships" do
    old_category = create(:example_category)
    old_tags = create_list(:example_tag, 2)
    example = create(
      :example,
      title: "Before",
      description: "Remove me",
      status: "archived",
      score: 99,
      category: old_category
    )
    old_tags.each { |tag| create(:example_tagging, example: example, example_tag: tag) }

    perform_put(
      example.id,
      put_document(id: example.id, title: "After", status: "active", score: 42)
    )

    expect(response).to have_http_status(:ok)
    resource = parsed_body.fetch("data")
    expect(resource.fetch("attributes")).to include(
      "title" => "After",
      "description" => nil,
      "status" => "active",
      "score" => 42
    )
    expect(resource.dig("relationships", "category", "data")).to be_nil
    expect(resource.dig("relationships", "tags", "data")).to eq([])

    example.reload
    expect(example.attributes.slice("title", "description", "status", "score", "category_id")).to eq(
      "title" => "After",
      "description" => nil,
      "status" => "active",
      "score" => 42,
      "category_id" => nil
    )
    expect(example.tags).to be_empty
  end

  it "uses model defaults for omitted replaceable status and score" do
    example = create(:example, title: "Before", status: "archived", score: 91)
    body = {
      data: {
        type: "examples",
        id: example.id,
        attributes: { title: "Defaulted" }
      }
    }

    perform_put(example.id, body)

    expect(response).to have_http_status(:ok)
    expect(example.reload.attributes.slice("title", "description", "status", "score")).to eq(
      "title" => "Defaulted",
      "description" => nil,
      "status" => "draft",
      "score" => 0
    )
  end

  it "canonicalizes uppercase UUIDs in Location and self" do
    uppercase_id = SecureRandom.uuid.upcase

    perform_put(uppercase_id, put_document(id: uppercase_id, title: "Canonical"))

    expect(response).to have_http_status(:created)
    resource = parsed_body.fetch("data")
    canonical_path = resource_path(uppercase_id.downcase)
    expect(resource.fetch("id")).to eq(uppercase_id.downcase)
    expect(resource.dig("links", "self")).to eq(canonical_path)
    expect(response.headers.fetch("Location")).to eq(canonical_path)
  end

  it "rolls back model and relationship replacement when the after hook fails" do
    original_category = create(:example_category)
    replacement_category = create(:example_category)
    original_tag = create(:example_tag)
    replacement_tag = create(:example_tag)
    example = create(:example, title: "Before", category: original_category)
    create(:example_tagging, example: example, example_tag: original_tag)
    relationships = {
      category: { data: { type: "exampleCategories", id: replacement_category.id } },
      tags: { data: [ { type: "exampleTags", id: replacement_tag.id } ] }
    }
    allow_any_instance_of(Api::V1::ExamplesController).to receive(:upsert_after_save)
      .and_raise(StandardError, "hook failure")

    perform_put(
      example.id,
      put_document(id: example.id, title: "After", relationships: relationships)
    )

    expect(response).to have_http_status(:internal_server_error)
    example.reload
    expect(example.title).to eq("Before")
    expect(example.category_id).to eq(original_category.id)
    expect(example.tag_ids).to eq([ original_tag.id ])
  end

  it "rolls back model and relationship replacement when serialization fails" do
    original_category = create(:example_category)
    replacement_category = create(:example_category)
    original_tag = create(:example_tag)
    replacement_tag = create(:example_tag)
    example = create(:example, title: "Before", category: original_category)
    create(:example_tagging, example: example, example_tag: original_tag)
    relationships = {
      category: { data: { type: "exampleCategories", id: replacement_category.id } },
      tags: { data: [ { type: "exampleTags", id: replacement_tag.id } ] }
    }
    allow(ExampleSerializer).to receive(:new).and_raise(StandardError, "serializer failure")

    perform_put(
      example.id,
      put_document(id: example.id, title: "After", relationships: relationships)
    )

    expect(response).to have_http_status(:internal_server_error)
    example.reload
    expect(example.title).to eq("Before")
    expect(example.category_id).to eq(original_category.id)
    expect(example.tag_ids).to eq([ original_tag.id ])
  end

  it "rejects a missing embedded relationship before replacing the resource" do
    example = create(:example, title: "Before", status: "active", score: 75)
    relationships = {
      category: { data: { type: "exampleCategories", id: SecureRandom.uuid } }
    }

    perform_put(
      example.id,
      put_document(id: example.id, title: "After", relationships: relationships)
    )

    expect(response).to have_http_status(:not_found)
    expect(parsed_body.fetch("errors").first).to include(
      "code" => "RELATIONSHIP_RESOURCE_NOT_FOUND",
      "source" => { "pointer" => "/data/relationships/category/data/id" }
    )
    expect(example.reload).to have_attributes(title: "Before", status: "active", score: 75)
  end

  describe "concurrent requests" do
    self.use_transactional_tests = false

    before do
      DatabaseCleaner.clean_with(:truncation)
      # 파일 최상위 before(9번째 줄)의 mock_bearer_user가 먼저 실행되고, 그 뒤 이
      # truncation이 방금 만든 User 행까지 지운다 — before 훅은 등록 순서(바깥
      # → 안쪽)대로 도는데 truncation이 안쪽에 있어서다. 두 스레드가 여기서
      # 진짜 DB 조회로 인증하므로(Bearer 토큰의 sub로 User 행을 찾는다)
      # truncation 뒤에 다시 만들어야 한다.
      mock_bearer_user
    end

    after do
      DatabaseCleaner.clean_with(:truncation)
    end

    it "serializes simultaneous PUTs to one committed row" do
      resource_id = SecureRandom.uuid
      category = create(:example_category)
      tag = create(:example_tag)
      relationships = {
        category: { data: { type: "exampleCategories", id: category.id } },
        tags: { data: [ { type: "exampleTags", id: tag.id } ] }
      }
      barrier = Concurrent::CyclicBarrier.new(2)
      bodies = [ "First", "Second" ].map do |title|
        put_document(id: resource_id, title: title, relationships: relationships)
      end
      expect(
        Rails.application.routes.recognize_path(resource_path(resource_id), method: :put)
      ).to include(controller: "api/v1/examples", action: "upsert")

      threads = bodies.map do |body|
        Thread.new do
          ActiveRecord::Base.connection_pool.with_connection do
            session = ActionDispatch::Integration::Session.new(Rails.application)
            barrier.wait
            session.put(
              resource_path(resource_id),
              params: body.to_json,
              headers: jsonapi_headers.merge(auth_bearer_headers)
            )
            [ session.response.status, JSON.parse(session.response.body) ]
          end
        end
      end

      results = threads.map(&:value)

      expect(results.map(&:first)).to contain_exactly(200, 201)
      expect(results).to all(satisfy { |(_, body)| body.dig("data", "id") == resource_id })
      expect(Example.where(id: resource_id).count).to eq(1)
      expect(Example.find(resource_id)).to have_attributes(category_id: category.id, tag_ids: [ tag.id ])
    ensure
      threads&.each { |thread| thread.join(5) }
    end
  end
end
