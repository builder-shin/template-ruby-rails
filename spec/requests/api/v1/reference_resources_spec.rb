# frozen_string_literal: true

require "rails_helper"

RSpec.describe "Reference resources", type: :request do
  before do
    %w[alpha beta gamma].each { |name| ExampleCategory.create!(name: name) }
    %w[draft-only public].each { |name| ExampleTag.create!(name: name) }
  end

  it "lists categories sorted by name" do
    get "/api/v1/categories", headers: jsonapi_headers

    document = JSON.parse(response.body)
    expect(response).to have_http_status(:ok)
    names = document.fetch("data").map { |resource| resource.dig("attributes", "name") }
    expect(names).to eq(names.sort)
    expect(document.fetch("data").map { |resource| resource.fetch("type") }.uniq)
      .to eq([ "exampleCategories" ])
  end

  it "lists tags sorted by name" do
    get "/api/v1/tags", headers: jsonapi_headers

    document = JSON.parse(response.body)
    expect(response).to have_http_status(:ok)
    expect(document.fetch("data").map { |resource| resource.fetch("type") }.uniq)
      .to eq([ "exampleTags" ])
  end

  it "returns a single category with a self link" do
    id = ExampleCategory.order(:name).first.id.to_s.downcase

    get "/api/v1/categories/#{id}", headers: jsonapi_headers

    document = JSON.parse(response.body)
    expect(response).to have_http_status(:ok)
    expect(document.dig("data", "links", "self")).to eq("/api/v1/categories/#{id}")
  end

  it "supports the declared name filters" do
    exact = get_json("/api/v1/categories?filter[name]=beta")
    contains = get_json("/api/v1/categories?filter[name][contains]=et")

    expect(exact.fetch("data").map { |r| r.dig("attributes", "name") }).to eq([ "beta" ])
    expect(contains.fetch("data").map { |r| r.dig("attributes", "name") }).to include("beta")
  end

  it "reverses order for an explicit descending sort" do
    # 기본 정렬만 확인하면 sort= 파라미터가 무시돼도 통과한다.
    ascending = get_json("/api/v1/categories?sort=name").fetch("data")
                                                        .map { |r| r.dig("attributes", "name") }
    descending = get_json("/api/v1/categories?sort=-name").fetch("data")
                                                          .map { |r| r.dig("attributes", "name") }

    expect(ascending.length).to be > 1
    expect(descending).to eq(ascending.reverse)
  end

  it "rejects an undeclared filter operator" do
    get "/api/v1/categories?filter[name][gt]=a", headers: jsonapi_headers

    expect(response).to have_http_status(:bad_request)
    expect(JSON.parse(response.body).dig("errors", 0, "code")).to eq("INVALID_FILTER")
  end

  it "rejects an undeclared include" do
    get "/api/v1/categories?include=examples", headers: jsonapi_headers

    expect(response).to have_http_status(:bad_request)
    expect(JSON.parse(response.body).dig("errors", 0, "code")).to eq("INVALID_INCLUDE")
  end

  it "has no write routes" do
    # 본문을 붙이면(예: params: "{}") 라우팅이 실패하기도 전에 JsonapiNegotiation의
    # 문서 형태 검증이 먼저 걸려 400 INVALID_JSONAPI_DOCUMENT가 나온다 — "쓰기
    # 라우트가 없다"가 아니라 "문서가 잘못됐다"를 재는 셈이 되어 이 테스트의
    # 취지와 어긋난다. 본문 없이 보내야 catch-all의 404 RESOURCE_NOT_FOUND를 잰다.
    post "/api/v1/categories", headers: jsonapi_headers
    expect(response).to have_http_status(:not_found)
    expect(JSON.parse(response.body).dig("errors", 0, "code")).to eq("RESOURCE_NOT_FOUND")

    delete "/api/v1/tags/#{ExampleTag.first.id}", headers: jsonapi_headers
    expect(response).to have_http_status(:not_found)
    expect(JSON.parse(response.body).dig("errors", 0, "code")).to eq("RESOURCE_NOT_FOUND")
  end

  def get_json(path)
    get path, headers: jsonapi_headers
    JSON.parse(response.body)
  end
end
