# frozen_string_literal: true

require "rails_helper"

RSpec.describe "Reference resources", type: :request do
  before do
    # 생성 순서를 이름의 알파벳 순서와 일부러 다르게 둔다(gamma가 첫 행). 두 순서가
    # 우연히 같으면 정렬 열 매핑이 created_at으로 잘못 바뀌어도(생성 순서 == 이름
    # 순서이므로) 출력이 똑같아 어떤 단언으로도 잡을 수 없다 — 아래 "reverses
    # order..." 테스트 참고.
    %w[gamma alpha beta].each { |name| ExampleCategory.create!(name: name) }
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
    names = document.fetch("data").map { |resource| resource.dig("attributes", "name") }
    expect(names).to eq(%w[draft-only public])
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

  it "does not emit a meta member on a single-category show" do
    # examples/{id}와 같은 이유 — CrudActions#jsonapi_meta 참고.
    id = ExampleCategory.order(:name).first.id.to_s.downcase

    get "/api/v1/categories/#{id}", headers: jsonapi_headers

    expect(response).to have_http_status(:ok)
    expect(JSON.parse(response.body)).not_to have_key("meta")
  end

  it "supports the declared name filters" do
    exact = get_json("/api/v1/categories?filter[name]=beta")
    contains = get_json("/api/v1/categories?filter[name][contains]=et")

    expect(exact.fetch("data").map { |r| r.dig("attributes", "name") }).to eq([ "beta" ])
    expect(contains.fetch("data").map { |r| r.dig("attributes", "name") }).to include("beta")
  end

  it "reverses order for an explicit descending sort" do
    # 리터럴 값을 박아 실제로 name 컬럼을 타는지 잰다. `ascending == ascending.sort`나
    # `descending == ascending.reverse`만 보면 query_contract의 "name" 매핑이
    # created_at 같은 다른 컬럼을 가리키도록 바뀌어도 통과해 버릴 여지가 있다 —
    # `descending == ascending.reverse`는 어느 컬럼으로 정렬하든 방향만 바꾸면
    # 항상 성립하므로 컬럼이 맞는지 자체는 전혀 재지 못한다. 이걸 실제로 잡으려면
    # `before`의 생성 순서가 이름 순서와 달라야 한다(위 코멘트) — 우연히 같았다면
    # 잘못된 컬럼으로 정렬해도 결과가 똑같아 리터럴 값조차 이 버그를 못 잡는다.
    ascending = get_json("/api/v1/categories?sort=name").fetch("data")
                                                        .map { |r| r.dig("attributes", "name") }
    descending = get_json("/api/v1/categories?sort=-name").fetch("data")
                                                          .map { |r| r.dig("attributes", "name") }

    expect(ascending).to eq(%w[alpha beta gamma])
    expect(descending).to eq(%w[gamma beta alpha])
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

  it "rejects an undeclared include on a single-category show" do
    # show의 jsonapi_query_mode가 :include_only인 것을 고정한다 — ExamplesController와
    # 맞춘 것이다. :none으로 되돌아가면 이 요청은 INVALID_INCLUDE가 아니라
    # INVALID_QUERY_PARAMETER가 되므로(모든 쿼리 파라미터를 거부), 이 테스트가 그
    # 회귀를 잡는다.
    id = ExampleCategory.order(:name).first.id.to_s.downcase

    get "/api/v1/categories/#{id}?include=bogus", headers: jsonapi_headers

    expect(response).to have_http_status(:bad_request)
    expect(JSON.parse(response.body).dig("errors", 0, "code")).to eq("INVALID_INCLUDE")
  end

  it "has no write routes" do
    # 본문을 붙이면(예: params: "{}") 라우팅이 실패하기도 전에 JsonapiNegotiation의
    # 문서 형태 검증이 먼저 걸려 400 INVALID_JSONAPI_DOCUMENT가 나온다 — "쓰기
    # 라우트가 없다"가 아니라 "문서가 잘못됐다"를 재는 셈이 되어 이 테스트의
    # 취지와 어긋난다. 본문 없이 보내야 알려진 경로의 405 HTTP_ERROR를 잰다.
    post "/api/v1/categories", headers: jsonapi_headers
    expect(response).to have_http_status(:method_not_allowed)
    expect(JSON.parse(response.body).dig("errors", 0, "code")).to eq("HTTP_ERROR")

    delete "/api/v1/tags/#{ExampleTag.first.id}", headers: jsonapi_headers
    expect(response).to have_http_status(:method_not_allowed)
    expect(JSON.parse(response.body).dig("errors", 0, "code")).to eq("HTTP_ERROR")
  end

  def get_json(path)
    get path, headers: jsonapi_headers
    JSON.parse(response.body)
  end
end
