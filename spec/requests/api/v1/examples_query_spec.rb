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

      def non_index_probe
        head :no_content
      end

      private

      def query_contract
        {
          filters: {
            "title" => { attribute: :title, type: :string, operators: %w[exact contains] },
            "status" => { attribute: :status, type: :enum, operators: %w[exact in] },
            "score" => { attribute: :score, type: :integer, operators: %w[exact gt gte lt lte in] },
            "category.id" => { attribute: :category_id, type: :uuid, operators: %w[exact in isNull] },
            "createdAt" => { attribute: :created_at, type: :datetime, operators: %w[exact gt gte lt lte] }
          },
          sorts: {
            "title" => { attribute: :title, nullable: false },
            "status" => { attribute: :status, nullable: false },
            "score" => { attribute: :score, nullable: false },
            "createdAt" => { attribute: :created_at, nullable: false },
            "updatedAt" => { attribute: :updated_at, nullable: false }
          },
          includes: %w[category tags],
          default_sort: [ { field: "createdAt", direction: :desc } ],
          tie_breaker: { field: "id", direction: :asc },
          default_page_size: 20
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
      post PROBE_PATH, to: "task_six_examples_query_probe#index"
      get "#{PROBE_PATH}/non_index", to: "task_six_examples_query_probe#non_index_probe"
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
    return unless document["errors"]&.any?

    error = document.fetch("errors").first
    expect(error).to include("status" => "400", "code" => code)
    expect(error.fetch("source")).to eq("parameter" => parameter)
  end

  def expect_jsonapi_error(status:, code:, parameter:)
    expect(response).to have_http_status(status)
    expect(response.headers.fetch("Content-Type")).to eq(JsonapiRequestHelper::JSONAPI_MEDIA_TYPE)
    document = parsed_body
    expect(document).to have_key("errors")
    return unless document["errors"]&.any?

    error = document.fetch("errors").first
    expect(error).to include("status" => status.to_s, "code" => code)
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

    # totalCount와 last 링크가 이 테스트의 주제이므로 page[totals]=true로 요청한다.
    first_page = request_document("page[totals]=true")
    expect(first_page.fetch("data").size).to eq(20)
    expect(first_page.fetch("meta")).to eq("totalCount" => 101)
    expect(first_page.fetch("links").keys).to eq(%w[self first prev next last])
    expect(first_page.dig("links", "prev")).to be_nil
    expect(decoded_link_query(first_page.dig("links", "self"))).to include(
      "page[number]" => "1",
      "page[size]" => "20"
    )
    expect(decoded_link_query(first_page.dig("links", "last"))).to include("page[number]" => "6")

    maximum_page = request_document("page[totals]=true&page[size]=200")
    expect(maximum_page.fetch("data").size).to eq(100)
    expect(maximum_page.fetch("meta")).to eq("totalCount" => 101)
    expect(decoded_link_query(maximum_page.dig("links", "self"))).to include("page[size]" => "100")

    last_page = request_document("page[number]=2&page[size]=100")
    expect(last_page.fetch("data").size).to eq(1)
    expect(last_page.dig("links", "next")).to be_nil
    expect(decoded_link_query(last_page.dig("links", "prev"))).to include("page[number]" => "1")
  end

  it "preserves non-page query parameters in every pagination link and uses null boundaries" do
    # last 링크가 모든 링크 종류를 도는 루프의 대상이므로 page[totals]=true로 요청한다.
    query = "page[totals]=true&filter[status][in]=draft,active&sort=title&include=category" \
            "&page[number]=2&page[size]=1"
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

    # decoded_link_query는 Hash로 모으므로 순서에는 눈이 멀다 — 여기서는 와이어 그대로의
    # 키 순서(보존된 파라미터가 원래 순서를 유지한 채 → page[totals] → page[number] →
    # page[size])를 정본과 맞춰 고정한다.
    expect(URI.decode_www_form(URI.parse(links.fetch("next")).query).map(&:first)).to eq(
      %w[filter[status][in] sort include page[totals] page[number] page[size]]
    )

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

  it "maps array and hash container conflicts in both orders for every query family" do
    cases = [
      [ "filter[]=10&filter[score]=20", "INVALID_FILTER", "filter[score]" ],
      [ "filter[score]=20&filter[]=10", "INVALID_FILTER", "filter[]" ],
      [ "page[]=1&page[number]=2", "INVALID_PAGE", "page[number]" ],
      [ "page[number]=2&page[]=1", "INVALID_PAGE", "page[]" ],
      [ "sort[]=score&sort[field]=title", "INVALID_SORT", "sort[field]" ],
      [ "sort[field]=title&sort[]=score", "INVALID_SORT", "sort[]" ],
      [ "include[]=category&include[path]=tags", "INVALID_INCLUDE", "include[path]" ],
      [ "include[path]=tags&include[]=category", "INVALID_INCLUDE", "include[]" ]
    ]

    aggregate_failures "container conflicts" do
      cases.each do |query, code, parameter|
        expect_query_error(query, code: code, parameter: parameter)
      end
    end
  end

  it "negotiates Accept before array and hash container conflicts for every query family" do
    queries = [
      "filter[]=10&filter[score]=20",
      "page[number]=2&page[]=1",
      "sort[]=score&sort[field]=title",
      "include[path]=tags&include[]=category"
    ]

    aggregate_failures "container conflict negotiation" do
      queries.each do |query|
        get "#{PROBE_PATH}?#{query}", headers: { "ACCEPT" => "application/json" }

        expect_jsonapi_error(status: 406, code: "NOT_ACCEPTABLE", parameter: "Accept")
      end
    end
  end

  it "negotiates Accept before classifying either filter shape conflict order" do
    queries = [
      "filter[score]=10&filter[score][gt]=20",
      "filter[score][gt]=20&filter[score]=10"
    ]

    queries.each do |query|
      aggregate_failures(query) do
        get "#{PROBE_PATH}?#{query}", headers: { "ACCEPT" => "application/json" }

        expect_jsonapi_error(status: 406, code: "NOT_ACCEPTABLE", parameter: "Accept")
      end
    end
  end

  it "negotiates a body-present write Content-Type before classifying a query shape conflict" do
    post "#{PROBE_PATH}?filter[score]=10&filter[score][gt]=20",
         params: { data: {} }.to_json,
         headers: {
           "ACCEPT" => JsonapiRequestHelper::JSONAPI_MEDIA_TYPE,
           "CONTENT_TYPE" => "application/json"
         }

    expect_jsonapi_error(status: 415, code: "UNSUPPORTED_MEDIA_TYPE", parameter: "Content-Type")
  end

  it "only emits strict query shape errors for the index action" do
    get "#{PROBE_PATH}/non_index?filter[score]=10&filter[score][gt]=20", headers: jsonapi_headers

    expect(response).to have_http_status(:no_content)

    get "#{PROBE_PATH}/non_index?filter[score]=10&filter[score][gt]=20",
        headers: { "ACCEPT" => "application/json" }

    expect_jsonapi_error(status: 406, code: "NOT_ACCEPTABLE", parameter: "Accept")
  end

  it "keeps controller lifecycle notifications for a compatible shape conflict" do
    events = []
    subscribers = %w[start_processing.action_controller process_action.action_controller].map do |event_name|
      ActiveSupport::Notifications.subscribe(event_name) do |*arguments|
        event = ActiveSupport::Notifications::Event.new(*arguments)
        events << event.name if event.payload[:controller] == "TaskSixExamplesQueryProbeController"
      end
    end

    get "#{PROBE_PATH}?filter[score]=10&filter[score][gt]=20", headers: jsonapi_headers

    expect_jsonapi_error(status: 400, code: "INVALID_FILTER", parameter: "filter[score][gt]")
    expect(events).to contain_exactly(
      "start_processing.action_controller",
      "process_action.action_controller"
    )
  ensure
    subscribers&.each { |subscriber| ActiveSupport::Notifications.unsubscribe(subscriber) }
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

  it "maps arbitrary scalar and nested query shape collisions without leaking Rails errors" do
    cases = [
      [ "unknown=value&unknown[field]=nested", "unknown[field]" ],
      [ "unknown[field]=nested&unknown=value", "unknown" ]
    ]

    cases.each do |query, parameter|
      aggregate_failures(query) do
        expect_query_error(query, code: "INVALID_QUERY_PARAMETER", parameter: parameter)
        expect(response.body).not_to include("ActionController::BadRequest", "Conflicting types")
      end
    end
  end

  it "keeps every column and type declaration inside the controller contract" do
    # 쿼리 엔진이 자원을 모른다는 것이 이 단계의 산출물이다. 공유 파서에 자원별
    # 상수가 남아 있으면 두 번째 자원을 추가하는 순간 합집합으로 부풀기 시작한다.
    source = Rails.root.join("app/lib/jsonapi/query_parser.rb").read

    expect(source).not_to include("FILTER_FIELDS")
    expect(source).not_to include("SORT_FIELDS")
    expect(source).not_to include("MAX_SCORE_INTEGER")
    expect(source).not_to match(/def parse_status/)
  end

  it "sorts by the contract's declared default when no sort is given" do
    # 기본 정렬이 파서에 하드코딩돼 있으면 categories의 `name ASC`를 낼 수 없다.
    contract = Api::V1::ExamplesController.new.send(:query_contract)

    expect(contract.fetch(:default_sort)).to eq([ { field: "createdAt", direction: :desc } ])
    expect(contract.fetch(:tie_breaker)).to eq({ field: "id", direction: :asc })
    expect(contract.fetch(:default_page_size)).to eq(20)
  end
end

RSpec.describe "Example JSON:API pagination contract", type: :request do
  # page_link이 URI.encode_www_form으로 대괄호를 퍼센트 인코딩하므로
  # 링크 문자열을 리터럴로 비교하지 않고 쿼리를 디코딩해 비교한다.
  def decoded_link_query(link)
    URI.decode_www_form(URI.parse(link).query).to_h
  end

  it "omits totals and the last link unless page[totals] asks for them" do
    # COUNT는 큰 테이블에서 목록 조회보다 비싸질 수 있다. 필요하다고 말한 요청에만
    # 실행한다 — 정본과 같은 계약이다.
    create_list(:example, 3)

    get "/api/v1/examples", headers: jsonapi_headers

    document = JSON.parse(response.body)
    expect(response).to have_http_status(:ok)
    expect(document).not_to have_key("meta")
    expect(document.fetch("links").fetch("last")).to be_nil
  end

  it "returns totals and a last link when page[totals] is true" do
    create_list(:example, 3)

    get "/api/v1/examples?page[totals]=true&page[size]=2", headers: jsonapi_headers

    document = JSON.parse(response.body)
    expect(response).to have_http_status(:ok)
    expect(document.fetch("meta")).to eq("totalCount" => 3)
    expect(decoded_link_query(document.fetch("links").fetch("last"))).to include("page[number]" => "2")
  end

  it "preserves page[totals]=true across every pagination link" do
    # next/prev/first/last/self 전부가 page[totals]=true를 그대로 들고 있어야
    # 그 링크를 따라간 다음 요청에서도 totals가 끊기지 않는다 — 정본과 같은 계약이다.
    create_list(:example, 5)

    get "/api/v1/examples?page[totals]=true&page[number]=2&page[size]=1", headers: jsonapi_headers

    document = JSON.parse(response.body)
    links = document.fetch("links")
    expect(links.keys).to eq(%w[self first prev next last])
    links.each_value do |link|
      expect(decoded_link_query(link)).to include("page[totals]" => "true")
    end

    # decoded_link_query는 Hash로 모으므로 순서에는 눈이 멀다 — 여기서는 와이어 그대로의
    # 키 순서(preserved → page[totals] → page[number] → page[size])를 정본과 맞춰 고정한다.
    expect(URI.decode_www_form(URI.parse(links.fetch("next")).query).map(&:first))
      .to eq(%w[page[totals] page[number] page[size]])
  end

  it "decides next from a probe row rather than a count" do
    # 요청 크기 +1행을 읽어 next 유무를 판정하고 그 한 행은 응답에서 버린다.
    create_list(:example, 3)

    get "/api/v1/examples?page[size]=2", headers: jsonapi_headers

    document = JSON.parse(response.body)
    expect(document.fetch("data").length).to eq(2)
    expect(decoded_link_query(document.fetch("links").fetch("next"))).to include("page[number]" => "2")

    get "/api/v1/examples?page[size]=3", headers: jsonapi_headers

    expect(JSON.parse(response.body).fetch("links").fetch("next")).to be_nil
  end

  it "rejects a non-boolean page[totals]" do
    get "/api/v1/examples?page[totals]=yes", headers: jsonapi_headers

    expect(response).to have_http_status(:bad_request)
    expect(JSON.parse(response.body).dig("errors", 0, "code")).to eq("INVALID_PAGE")
  end

  it "omits meta from an empty collection unless page[totals] asks for it" do
    # 짧은 경로(빈 컬렉션)는 render의 short-circuit(`options.slice(:meta, :links).compact`)을
    # 지난다. `meta`가 없을 때 `{}`로 새지 않는지 여기서 확인한다.
    get "/api/v1/examples", headers: jsonapi_headers

    document = JSON.parse(response.body)
    expect(response).to have_http_status(:ok)
    expect(document.fetch("data")).to eq([])
    expect(document).not_to have_key("meta")
  end

  it "reports zero totalCount for an empty collection when page[totals] is true" do
    get "/api/v1/examples?page[totals]=true", headers: jsonapi_headers

    document = JSON.parse(response.body)
    expect(response).to have_http_status(:ok)
    expect(document.fetch("data")).to eq([])
    expect(document.fetch("meta")).to eq("totalCount" => 0)
  end

  it "walks the whole collection by cursor" do
    # 커서는 유효 정렬의 컬럼 값들을 인코딩한 opaque 문자열이다. 클라이언트는
    # 커서를 만들지 않고 links를 따라간다.
    create_list(:example, 5)

    seen = []
    url = "/api/v1/examples?page[size]=2&page[after]="
    while url
      get url, headers: jsonapi_headers
      document = JSON.parse(response.body)
      expect(response).to have_http_status(:ok)
      seen.concat(document.fetch("data").map { |resource| resource.fetch("id") })
      url = document.fetch("links").fetch("next")
    end

    get "/api/v1/examples?page[size]=100", headers: jsonapi_headers
    expected = JSON.parse(response.body).fetch("data").map { |resource| resource.fetch("id") }
    expect(seen).to eq(expected)
  end

  it "walks the whole collection by cursor under a mixed-direction multi-key sort" do
    # 선두 정렬 컬럼(status, 오름차순)에 값이 반복되고 둘째 컬럼(score, 내림차순)이
    # 방향을 뒤집는다 — keyset 술어에 붙인 선두 경계(leading bound)의 부등호가
    # 잘못된 방향이면 이 순회에서 행이 사라지거나 중복된다.
    statuses = %w[draft active archived]
    9.times { |index| create(:example, status: statuses[index % statuses.length], score: index * 10) }

    seen = []
    url = "/api/v1/examples?sort=status,-score&page[size]=2&page[after]="
    while url
      get url, headers: jsonapi_headers
      expect(response).to have_http_status(:ok)
      document = JSON.parse(response.body)
      seen.concat(document.fetch("data").map { |resource| resource.fetch("id") })
      url = document.fetch("links").fetch("next")
    end

    get "/api/v1/examples?sort=status,-score&page[size]=100", headers: jsonapi_headers
    expected = JSON.parse(response.body).fetch("data").map { |resource| resource.fetch("id") }
    expect(seen).to eq(expected)
  end

  it "rejects a cursor combined with page[number]" do
    get "/api/v1/examples?page[after]=&page[number]=2", headers: jsonapi_headers

    expect(response).to have_http_status(:bad_request)
    expect(JSON.parse(response.body).dig("errors", 0, "code")).to eq("INVALID_PAGE")
  end

  it "rejects combining page[after] and page[before] in either order" do
    # 이름이 다른 두 파라미터라 @seen_page_parameters 중복 검사만으로는 잡히지
    # 않는다 — 커서 슬롯 자체가 이미 찼는지를 따로 봐야 한다.
    queries = [ "page[after]=&page[before]=", "page[before]=&page[after]=" ]

    queries.each do |query|
      aggregate_failures(query) do
        get "/api/v1/examples?#{query}", headers: jsonapi_headers

        expect(response).to have_http_status(:bad_request)
        expect(JSON.parse(response.body).dig("errors", 0, "code")).to eq("INVALID_PAGE")
      end
    end
  end

  it "rejects a cursor whose signature does not match the effective sort" do
    create_list(:example, 3)
    get "/api/v1/examples?page[size]=1&page[after]=", headers: jsonapi_headers
    cursor = JSON.parse(response.body).fetch("links").fetch("next")[/page%5Bafter%5D=([^&]*)/, 1]

    get "/api/v1/examples?page[size]=1&sort=title&page[after]=#{cursor}", headers: jsonapi_headers

    expect(response).to have_http_status(:bad_request)
    expect(JSON.parse(response.body).dig("errors", 0, "code")).to eq("INVALID_PAGE")
  end

  it "rejects a malformed cursor" do
    get "/api/v1/examples?page[after]=not-base64url!!", headers: jsonapi_headers

    expect(response).to have_http_status(:bad_request)
    expect(JSON.parse(response.body).dig("errors", 0, "code")).to eq("INVALID_PAGE")
  end

  it "has a null prev link on the first cursor page" do
    # 정본은 들어온 커서가 비어 있지 않을 때만 prev를 낸다. 컬렉션의 처음(빈
    # 커서)에서는 offset 모드 1페이지처럼 prev가 없어야 한다.
    create_list(:example, 3)

    get "/api/v1/examples?page[after]=", headers: jsonapi_headers

    expect(response).to have_http_status(:ok)
    expect(JSON.parse(response.body).dig("links", "prev")).to be_nil
  end

  it "has a non-null prev link on the second cursor page" do
    create_list(:example, 3)

    get "/api/v1/examples?page[size]=1&page[after]=", headers: jsonapi_headers
    next_link = JSON.parse(response.body).fetch("links").fetch("next")
    expect(next_link).not_to be_nil

    get next_link, headers: jsonapi_headers

    expect(response).to have_http_status(:ok)
    expect(JSON.parse(response.body).dig("links", "prev")).not_to be_nil
  end

  it "echoes the incoming cursor verbatim in the self link" do
    create_list(:example, 3)

    get "/api/v1/examples?page[size]=1&page[after]=", headers: jsonapi_headers
    first_page = JSON.parse(response.body)
    expect(decoded_link_query(first_page.dig("links", "self"))).to include("page[after]" => "")

    next_link = first_page.fetch("links").fetch("next")
    raw_cursor = decoded_link_query(next_link).fetch("page[after]")

    get next_link, headers: jsonapi_headers
    second_page = JSON.parse(response.body)

    expect(decoded_link_query(second_page.dig("links", "self"))).to include("page[after]" => raw_cursor)
  end

  it "always exposes a last link pointing at the end of the collection in cursor mode" do
    # 총 개수를 몰라도 last를 만들 수 있다 — 빈 문자열이 컬렉션의 끝을 가리킨다.
    create_list(:example, 3)

    get "/api/v1/examples?page[after]=", headers: jsonapi_headers

    expect(decoded_link_query(JSON.parse(response.body).dig("links", "last"))).to include("page[before]" => "")
  end

  it "returns the last page and a null next link for page[before]=" do
    create_list(:example, 5)

    get "/api/v1/examples?page[size]=2&page[before]=", headers: jsonapi_headers
    expect(response).to have_http_status(:ok)
    last_page = JSON.parse(response.body)

    get "/api/v1/examples?page[size]=100", headers: jsonapi_headers
    all_ids = JSON.parse(response.body).fetch("data").map { |resource| resource.fetch("id") }

    expect(last_page.dig("links", "next")).to be_nil
    expect(last_page.fetch("data").map { |resource| resource.fetch("id") }).to eq(all_ids.last(2))
  end

  it "supports page[totals]=true in cursor mode across every link" do
    create_list(:example, 5)

    get "/api/v1/examples?page[after]=&page[totals]=true&page[size]=2", headers: jsonapi_headers
    expect(response).to have_http_status(:ok)
    expect(JSON.parse(response.body).fetch("meta")).to eq("totalCount" => 5)
    first_next = JSON.parse(response.body).fetch("links").fetch("next")

    # 두 번째 페이지를 쓴다 — 첫 페이지는 prev가 nil이라 다섯 링크 전부를
    # 순회하는 아래 루프가 nil에 decoded_link_query를 호출하게 된다.
    get first_next, headers: jsonapi_headers
    second_page = JSON.parse(response.body)

    expect(response).to have_http_status(:ok)
    expect(second_page.fetch("meta")).to eq("totalCount" => 5)
    links = second_page.fetch("links")
    expect(links.keys).to eq(%w[self first prev next last])
    links.each_value do |link|
      expect(decoded_link_query(link)).to include("page[totals]" => "true")
    end
  end
end
