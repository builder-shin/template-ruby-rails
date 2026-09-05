# Rails JSON:API 계층 계약 통일 구현 계획 (C1)

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** 쿼리 엔진에서 Example 전용 지식을 걷어내고, 페이지네이션 계약을 정본(FastAPI)과 같게 만들고, `categories`·`tags` 읽기 라우트를 연다.

**Architecture:** `JsonapiQuery`가 모든 자원이 공유하는 concern인데 Example의 컬럼·타입·기본 정렬을 상수로 갖고 있다. 그것을 자원별 `query_contract`로 옮겨 엔진이 자원을 모르게 만든 뒤, 그 위에 probe 기반 offset과 keyset cursor를 얹고, 마지막으로 참조 자원 둘을 선언만으로 올린다. 549줄짜리 단일 파일은 cursor를 얹기 전에 먼저 쪼갠다.

**Tech Stack:** Rails 8, PostgreSQL, RSpec, rswag, RuboCop, Brakeman

**Spec:** `docs/superpowers/specs/2026-09-04-contract-parity-design.md` — 단계 1·2·4

## 이 계획의 범위 — 스펙을 둘로 나눈다

스펙은 네 단계를 담고 있고 그중 **단계 3(인증 이식)은 독립된 하위 시스템**이다. 스펙 §3이 스스로 그렇게 말한다 — *"2와 3은 건드리는 파일이 겹치지 않아(`app/lib/jsonapi/` vs `app/auth/`) 서로 독립이다."*

단계 3은 새 파일 12개, 삭제 6개, JWT·argon2·refresh 회전·재사용 감지·Sidekiq job을 포함한다. 그 하나가 다른 세 단계를 합친 것보다 크다.

- **이 계획(C1)** — 단계 1 · 2 · 4. JSON:API 쿼리 계층.
- **다음 계획(C2)** — 단계 3. 인증 이식.

**둘 사이의 유일한 인수인계:** 이 계획이 만드는 두 컨트롤러는 `ApiController`를 상속하므로 `before_action :set_current_user`를 물려받는다. 읽기 전용 공개 자원이 매 요청마다 외부 auth 서비스를 부르면 안 되므로 `skip_before_action :set_current_user`를 선언한다(`ExamplesController:21`이 같은 이유로 같은 줄을 갖고 있다). C2가 그 콜백 자체를 없앨 때 이 두 줄도 함께 지워야 한다 — `skip_before_action`은 없는 콜백을 건너뛰려 하면 `ArgumentError`를 낸다. C2 계획에 이 항목을 명시한다.

## Global Constraints

- 완료 조건은 하나다 — **같은 요청에 정본과 같은 문서가 나온다.**
- 리소스 스키마(`title` · `description` · `status` · `score`)와 status enum(`draft` / `active` / `archived`)은 **이미 정본과 일치한다. 건드리지 않는다.**
- 단계 1은 **공개 응답이 한 바이트도 달라지지 않는다.** 기존 request spec 전부가 안전망이다. 이 단계에서 응답이 바뀌면 그것은 버그다.
- `links.last`와 `meta.totalCount`는 `page[totals]=true`일 때만 나온다.
- 커서: `page[after]` · `page[before]`. 빈 문자열은 각각 컬렉션의 시작과 끝이다. `page[number]`와 함께 오면 `INVALID_PAGE`.
- **정렬 컬럼이 NULL을 허용하면 커서 모드를 거부한다.** Example의 정렬 컬럼은 전부 NOT NULL이라 실제로는 걸리지 않지만, 규칙이 코드에 있어야 나중에 nullable 정렬을 여는 사람이 막힌다.
- 커서 코덱이 왕복시킬 수 없는 타입의 정렬도 거부한다. 이유가 다르다 — nullable은 행을 건너뛰는 문제이고, 이쪽은 `next` 링크를 아예 발행할 수 없는 문제다.
- `default_page_size`는 20, `MAX_PAGE_SIZE`는 100. **둘 다 이미 그 값이다.**
- `id`는 tie breaker 전용이다. **이미 그렇다** — `query_contract[:sorts]`에 `id`가 없어 `sort=id`가 이미 거부된다.
- 참조 자원 조회 정책: filters `name`[exact, contains] / sorts `name` · `createdAt` / default `name ASC` / tie breaker `id ASC` / includes 없음.
- 참조 자원에 **새 인덱스를 만들지 않는다.** 근거가 "기존 인덱스로 커버된다"가 **아니다** — PostgreSQL은 유니크 제약을 근거로 뒤따르는 정렬 키를 지우지 않으므로 `ORDER BY name, id`에는 incremental sort가 남는다. 실제 이유는 `name`이 유니크해서 동점 그룹이 항상 1이고 참조 테이블의 행 수가 작다는 것이다. 이 근거를 정책 선언부 주석에 남긴다.
- 참조 자원에 쓰기 라우트와 관계 라우트를 만들지 않는다.
- `fields[...]` 희소 필드셋을 추가하지 않는다.
- workspace 멀티테넌시의 대체물을 만들지 않는다.
- `rack-cors`와 `CORS_ALLOWED_ORIGINS`를 유지한다 — 배포 설정이지 JSON:API 계약이 아니다.
- **검증 게이트는 넷이다.** 순서대로: `bundle exec rspec` → `bundle exec rails rswag:specs:swaggerize` + `git diff --exit-code -- swagger/v1/swagger.yaml` → `bundle exec brakeman --no-pager -q` → `bundle exec rubocop`.

## 스펙의 오류 두 건 — 이 계획이 정정한다

계획을 쓰면서 소스와 대조한 결과 스펙 두 곳이 사실과 다르다. 스펙이 구속력 있는 권위지만, 사실 주장이 틀린 자리는 사실이 이긴다.

**1. §1.1 표가 "`meta.totalCount` 없음"이라고 한다 — 있다, 그것도 무조건.**

`app/controllers/concerns/crud_actions.rb:62`가 `meta: { totalCount: result.total_count }`를 항상 렌더한다. 세 spec이 그것을 단언하고(`spec/requests/api/v1/examples_query_spec.rb:290,301,316`) `spec/swagger_helper.rb:367-368`이 `totalCount`를 **required**로 고정한다.

따라서 단계 2의 일은 `meta.totalCount`를 **추가**하는 것이 아니라 **기본 경로에서 제거**하고 `page[totals]=true`에만 남기는 것이다. 그리고 swagger 스키마의 `required`도 함께 풀어야 한다 — 이것을 빠뜨리면 게이트의 swagger 단계가 깨진다.

**2. §7이 "`CrudActions`에 읽기 전용 옵션을 추가"하라고 한다 — Rails에는 필요 없다.**

그 문장은 FastAPI와 NestJS에서 옮겨 온 것이다. 두 저장소는 base class가 라우트를 **등록**하므로 등록을 끄는 옵션이 필요했다. Rails는 `config/routes.rb`가 라우트를 선언하므로, 읽기 전용은 `resources :categories, only: %i[index show]`라고 쓰는 것 그 자체다.

`ApiController`가 `include CrudActions`를 하므로 두 컨트롤러도 write 액션 메서드를 물려받지만, 라우트가 없으면 도달할 수 없는 죽은 메서드일 뿐이다. `CrudActions`를 고치지 않는다.

## 파일 구조

| 파일 | 책임 | 태스크 |
| --- | --- | --- |
| `app/controllers/concerns/jsonapi_query.rb` (수정) | concern 진입점과 액션별 검증만 남긴다 | 1 |
| `app/lib/jsonapi/raw_query.rb` (생성) | `RawQuery` + `ShapeTree` — 쿼리 문자열 디코딩과 형태 충돌 판정 | 1 |
| `app/lib/jsonapi/query_parser.rb` (생성) | 파싱과 scope 적용 | 1, 2 |
| `app/lib/jsonapi/pagination.rb` (생성) | offset · probe · 링크 조립 | 1, 3 |
| `app/lib/jsonapi/cursor.rb` (생성) | 커서 인코딩·디코딩, keyset 술어 | 4 |
| `app/controllers/api/v1/examples_controller.rb` (수정) | 풍부해진 `query_contract` | 2 |
| `app/controllers/concerns/crud_actions.rb` (수정) | `meta`와 `links`를 조건부로 | 3 |
| `app/controllers/api/v1/example_categories_controller.rb` (생성) | 선언만. 읽기 전용 | 5 |
| `app/controllers/api/v1/example_tags_controller.rb` (생성) | 선언만. 읽기 전용 | 5 |
| `app/serializers/example_category_serializer.rb` (수정) | `self` 링크 | 5 |
| `app/serializers/example_tag_serializer.rb` (수정) | `self` 링크 | 5 |
| `config/routes.rb` (수정) | 두 자원의 읽기 라우트 | 5 |
| `Gemfile` (수정) | 쓰이지 않는 `kaminari` 제거 | 3 |

---

### Task 1: `jsonapi_query.rb` 파일 분할

**Files:**
- Modify: `app/controllers/concerns/jsonapi_query.rb` (549줄 → ~130줄)
- Create: `app/lib/jsonapi/raw_query.rb`
- Create: `app/lib/jsonapi/query_parser.rb`
- Create: `app/lib/jsonapi/pagination.rb`
- Test: 기존 spec 전부가 안전망 (새 spec 없음)

**Interfaces:**
- Consumes: 없음 (첫 작업)
- Produces:
  - `Jsonapi::RawQuery` — `.decode(query_string)`, `.shape_conflict(pairs)`, `.sanitize_shape_conflicts(pairs)`
  - `Jsonapi::QueryParser` — `.new(scope:, request:, action_params:, contract:, model:).call → Jsonapi::QueryResult`
  - `Jsonapi::QueryResult = Data.define(:scope, :includes, :total_count, :links, :include_requested)`
  - `Jsonapi::Pagination` — offset 계산과 링크 조립. Task 3이 probe를 여기 얹는다.

**이 태스크는 순수 이동이다.** 로직을 한 줄도 바꾸지 않는다. cursor를 얹으면 이 파일이 700줄을 넘으므로 그 전에 쪼갠다 — 스펙 §5.3.

Rails는 `app/*` **각각을** Zeitwerk 루트로 등록한다(`paths.add "app", glob: "{*,*/concerns}"`). 따라서 `app/jsonapi/raw_query.rb`는 최상위 `RawQuery`를 정의해야 하고, `Jsonapi::RawQuery`를 넣으면 `NameError`가 난다 — 저장소 안의 증거는 `app/errors/json_api_error.rb`가 최상위 `JsonApiError`를 정의한다는 것이다. `app/lib`는 그 자체가 루트이므로 `app/lib/jsonapi/raw_query.rb` → `Jsonapi::RawQuery`가 설정 한 줄 없이 성립한다. 덤으로 SimpleCov의 `track_files "app/**/*.rb"`에도 걸린다 — 최상위 `lib/`에 두었다면 커버리지 추적에서 조용히 빠졌을 자리다.

- [ ] **Step 1: 기존 spec이 통과하는 것을 먼저 확인한다**

Run: `bundle exec rspec`

Expected: 전부 통과. 이것이 이 태스크의 안전망이므로 시작점이 초록인지부터 본다. 빨간 것이 있으면 그것은 이 태스크의 red가 아니라 사전 상태이므로 **그 자리에서 멈추고 보고한다.**

- [ ] **Step 2: `app/lib/jsonapi/raw_query.rb`를 만든다**

`jsonapi_query.rb`의 `RawQuery` 클래스(136-239행)와 그 안의 `ShapeTree`를 통째로 옮긴다. 클래스 본문은 **한 글자도 바꾸지 않는다.** 감싸는 모듈만 더한다.

```ruby
# frozen_string_literal: true

require "uri"

module Jsonapi
  # 쿼리 문자열을 디코딩하고 파라미터 형태 충돌을 판정한다.
  #
  # `filter[a]=1&filter[a][gt]=2`처럼 같은 이름이 스칼라와 컨테이너 양쪽으로 오면
  # Rack이 조용히 한쪽을 버린다. 그것을 형태 충돌로 잡아 400으로 만드는 것이
  # `ShapeTree`의 일이다.
  class RawQuery
    ERROR_CODE_BY_FAMILY = {
      "filter" => "INVALID_FILTER",
      "sort" => "INVALID_SORT",
      "include" => "INVALID_INCLUDE",
      "page" => "INVALID_PAGE"
    }.freeze
    PARAMETER = /\A([^\[\]]+)((?:\[[^\[\]]*\])*)\z/
    SEGMENT = /\[([^\[\]]*)\]/

    class ShapeTree
      class Node
        attr_accessor :terminal, :container_kind
        attr_reader :children

        def initialize
          @terminal = false
          @container_kind = nil
          @children = {}
        end
      end
      private_constant :Node

      def initialize
        @root = Node.new
      end

      def conflict?(segments)
        node = @root
        segments.each do |segment|
          return true if node.terminal

          kind = container_kind(segment)
          return true if node.container_kind && node.container_kind != kind

          node = node.children[segment]
          return false unless node
        end

        !node.container_kind.nil?
      end

      def add(segments)
        node = @root
        segments.each do |segment|
          node.container_kind ||= container_kind(segment)
          node = node.children[segment] ||= Node.new
        end
        node.terminal = true
      end

      private

      def container_kind(segment)
        segment.empty? ? :array : :hash
      end
    end
    private_constant :ShapeTree

    class << self
      def decode(query_string)
        return [] if query_string.empty?

        pairs = URI.decode_www_form(query_string, Encoding::UTF_8)
        raise ArgumentError unless pairs.flatten.all?(&:valid_encoding?)

        pairs
      end

      def shape_conflict(pairs)
        sanitize_shape_conflicts(pairs).first
      end

      def sanitize_shape_conflicts(pairs)
        conflict = nil
        shape_trees = {}
        sanitized_pairs = pairs.reject do |parameter, _|
          segments = parameter_segments(parameter)
          next false unless segments

          family = segments.first
          shape_tree = shape_trees[family] ||= ShapeTree.new
          if shape_tree.conflict?(segments.drop(1))
            conflict ||= [ ERROR_CODE_BY_FAMILY.fetch(family, "INVALID_QUERY_PARAMETER"), parameter ]
            next true
          end

          shape_tree.add(segments.drop(1))
          false
        end

        [ conflict, sanitized_pairs ]
      end

      private

      def parameter_segments(parameter)
        match = PARAMETER.match(parameter)
        return unless match

        [ match[1], *match[2].scan(SEGMENT).flatten ]
      end
    end
  end
end
```

- [ ] **Step 3: `app/lib/jsonapi/pagination.rb`를 만든다**

지금은 offset 계산과 링크 조립만 담는다. Task 3이 probe를 여기 얹는다.

```ruby
# frozen_string_literal: true

require "uri"

module Jsonapi
  # offset 페이지네이션의 scope 적용과 링크 조립.
  #
  # Task 3이 여기에 probe(요청 크기 +1행을 읽어 `next` 유무를 판정)를 얹는다.
  # 지금은 `QueryParser`에서 그대로 옮겨 온 로직뿐이다.
  module Pagination
    DEFAULT_PAGE_SIZE = 20
    MAX_PAGE_SIZE = 100
    MAX_SQL_INTEGER = (2**63) - 1

    module_function

    def apply(scope, page_number:, page_size:)
      scope.offset((page_number - 1) * page_size).limit(page_size)
    end

    def links(request:, raw_pairs:, page_number:, page_size:, total_count:)
      last_page = [ 1, (total_count + page_size - 1) / page_size ].max
      {
        "self" => page_link(request, raw_pairs, page_number, page_size),
        "first" => page_link(request, raw_pairs, 1, page_size),
        "prev" => page_number > 1 ? page_link(request, raw_pairs, page_number - 1, page_size) : nil,
        "next" => page_number < last_page ? page_link(request, raw_pairs, page_number + 1, page_size) : nil,
        "last" => page_link(request, raw_pairs, last_page, page_size)
      }
    end

    def page_link(request, raw_pairs, number, size)
      preserved = raw_pairs.reject { |parameter, _| parameter == "page" || parameter.start_with?("page[") }
      query = URI.encode_www_form(
        [ *preserved, [ "page[number]", number.to_s ], [ "page[size]", size.to_s ] ]
      )
      "#{request.path}?#{query}"
    end
  end
end
```

- [ ] **Step 4: `app/lib/jsonapi/query_parser.rb`를 만든다**

`jsonapi_query.rb`의 `Parser` 클래스(242-548행)를 옮긴다. **다섯 곳만 바꾼다:**

1. 클래스 이름 `Parser` → `Jsonapi::QueryParser`
2. `Result` → `Jsonapi::QueryResult` (아래에서 정의)
3. `RawQuery` 참조 → `Jsonapi::RawQuery`
4. `apply_pagination`과 `pagination_links` 본문 → `Jsonapi::Pagination`에 위임
5. `DEFAULT_PAGE_SIZE` · `MAX_PAGE_SIZE` · `MAX_SQL_INTEGER` 참조 → `Jsonapi::Pagination::` 접두

나머지 상수(`FILTER_PARAMETER` · `POSITIVE_INTEGER` · `INTEGER` · `UUID` · `DATETIME_WITH_OFFSET` · `MAX_SCORE_INTEGER` · `FILTER_FIELDS` · `SORT_FIELDS`)와 `FilterClause` · `SortTerm`은 이 파일로 함께 옮긴다. Task 2가 그중 셋을 지운다.

```ruby
# frozen_string_literal: true

require "time"
require "set"

module Jsonapi
  QueryResult = Data.define(:scope, :includes, :total_count, :links, :include_requested)

  # JSON:API 조회 파라미터를 파싱해 scope에 적용한다.
  #
  # 무엇을 질의할 수 있는지는 컨트롤러의 `query_contract`가 정하고, 이 클래스는
  # 그 선언을 해석만 한다. 사용자가 보낸 문자열은 선언의 키를 찾는 데만 쓰이고
  # SQL에 들어가는 것은 선언이 들고 있는 컬럼 이름이다.
  class QueryParser
    FILTER_PARAMETER = /\Afilter\[([^\[\]]+)\](?:\[([^\[\]]+)\])?\z/
    POSITIVE_INTEGER = /\A[0-9]+\z/
    INTEGER = /\A[+-]?[0-9]+\z/
    UUID = /\A[0-9a-f]{8}(?:-[0-9a-f]{4}){3}-[0-9a-f]{12}\z/i
    DATETIME_WITH_OFFSET = /\A\d{4}-\d{2}-\d{2}T.+(?:Z|[+-]\d{2}:\d{2})\z/
    MAX_SCORE_INTEGER = (2**31) - 1

    FILTER_FIELDS = {
      "title" => { attribute: :title, type: :string },
      "status" => { attribute: :status, type: :status },
      "score" => { attribute: :score, type: :integer },
      "category.id" => { attribute: :category_id, type: :uuid },
      "createdAt" => { attribute: :created_at, type: :datetime }
    }.freeze
    SORT_FIELDS = {
      "title" => :title,
      "status" => :status,
      "score" => :score,
      "createdAt" => :created_at,
      "updatedAt" => :updated_at,
      "id" => :id
    }.freeze

    FilterClause = Data.define(:name, :operator, :value)
    SortTerm = Data.define(:name, :descending)
    private_constant :FilterClause, :SortTerm

    # 이하 본문은 기존 `Parser`와 동일하다. 위 다섯 변경만 적용한다.
  end
end
```

`apply_pagination`과 `pagination_links`는 위임 형태가 된다.

```ruby
    def apply_pagination(scope)
      Pagination.apply(scope, page_number: @page_number, page_size: @page_size)
    end

    def pagination_links(total_count)
      Pagination.links(
        request: @request,
        raw_pairs: @raw_pairs,
        page_number: @page_number,
        page_size: @page_size,
        total_count: total_count
      )
    end
```

`@page_size = DEFAULT_PAGE_SIZE`는 `@page_size = Pagination::DEFAULT_PAGE_SIZE`가 되고, `parse_page`의 `MAX_PAGE_SIZE`·`parse_positive_integer`와 `validate_page_offset!`의 `MAX_SQL_INTEGER`도 같은 접두를 받는다.

`Result.new(...)`는 `QueryResult.new(...)`가 된다.

- [ ] **Step 5: `jsonapi_query.rb`를 진입점만 남기고 줄인다**

남는 것: `included do` 블록, `process_action`, `jsonapi_query`, `prepare_jsonapi_query_shape_conflict`, `raise_pending_jsonapi_query_shape_conflict`, `validate_jsonapi_action_query!`, `validate_include_only_query!`.

사라지는 것: 모든 상수, `Result` · `FilterClause` · `SortTerm`, `RawQuery` 클래스, `Parser` 클래스.

```ruby
# frozen_string_literal: true

require "uri"

# JSON:API 조회 파라미터의 concern 진입점.
#
# 파싱과 scope 적용은 `Jsonapi::QueryParser`가, 쿼리 문자열 디코딩과 형태 충돌
# 판정은 `Jsonapi::RawQuery`가, 페이지네이션은 `Jsonapi::Pagination`이 소유한다.
# 여기 남은 것은 Rails 콜백에 붙는 진입점과 액션별 검증뿐이다.
module JsonapiQuery
  extend ActiveSupport::Concern

  included do
    before_action :raise_pending_jsonapi_query_shape_conflict
    before_action :validate_jsonapi_action_query!
  end

  private

  def process_action(*)
    prepare_jsonapi_query_shape_conflict
    super
  end

  def jsonapi_query(scope)
    Jsonapi::QueryParser.new(
      scope: scope,
      request: request,
      action_params: -> { params },
      contract: query_contract,
      model: klass
    ).call
  end
```

이하 네 메서드는 기존 본문 그대로 옮기되, `RawQuery.` 참조를 `Jsonapi::RawQuery.`로 바꾼다.

- [ ] **Step 6: 전체 spec이 통과하는 것을 확인한다**

Run: `bundle exec rspec`

Expected: 전부 통과. **한 건이라도 실패하면 이동 중 무언가를 바꾼 것이다.** 이 태스크는 로직을 바꾸지 않으므로 실패는 곧 실수다.

- [ ] **Step 7: 게이트 나머지를 돌린다**

Run: `bundle exec rubocop && bundle exec brakeman --no-pager -q`

Expected: 둘 다 통과. rubocop이 새 파일의 스타일을 지적하면 지적대로 고친다 — 이 저장소의 스타일 설정이 권위다.

swagger는 이 태스크에서 재생성할 필요가 없다. 공개 계약이 바뀌지 않았기 때문이다. 그래도 한 번 돌려 diff가 비는 것을 확인하면 "계약 불변"이 실증된다.

Run: `bundle exec rails rswag:specs:swaggerize && git diff --exit-code -- swagger/v1/swagger.yaml`

Expected: diff 없음.

- [ ] **Step 8: 커밋**

```bash
git add app/controllers/concerns/jsonapi_query.rb app/lib/jsonapi/
git commit -m "refactor: split the JSON:API query concern into focused files

jsonapi_query.rb가 549줄에 RawQuery·ShapeTree·Parser 세 클래스를 담고 있었다.
cursor를 얹으면 700줄을 넘으므로 그 전에 쪼갠다.

로직을 한 줄도 바꾸지 않았다. 공개 응답이 달라지지 않는 것을 기존 request
spec 전부와 swagger diff가 비는 것으로 확인했다."
```

---

### Task 2: 쿼리 계약 탈-Example화

**Files:**
- Modify: `app/lib/jsonapi/query_parser.rb`
- Modify: `app/controllers/api/v1/examples_controller.rb:48-60`
- Test: 기존 spec 전부가 안전망

**Interfaces:**
- Consumes: Task 1의 `Jsonapi::QueryParser`
- Produces: 새 `query_contract` 모양 — 컨트롤러가 컬럼·타입·기본 정렬·tie breaker·기본 페이지 크기를 전부 선언한다. Task 5의 두 컨트롤러가 이 모양을 쓴다.

```ruby
{
  filters: { "<공개 이름>" => { attribute: <심볼>, type: <심볼>, operators: %w[...] } },
  sorts:   { "<공개 이름>" => { attribute: <심볼>, nullable: <bool> } },
  includes: %w[...],
  default_sort: [ { field: "<공개 이름>", direction: :asc | :desc } ],
  tie_breaker:  { field: "<공개 이름>", direction: :asc | :desc },
  default_page_size: <정수>
}
```

`tie_breaker.field`는 `sorts`에 없어도 된다 — `id`가 그 경우다. 파서는 `sorts`에 없으면 공개 이름을 그대로 컬럼 이름으로 쓴다.

**공개 응답이 한 바이트도 달라지지 않는다.** 스펙 §4.3이 이 단계의 계약이다.

- [ ] **Step 1: 실패하는 테스트를 쓴다**

`spec/requests/api/v1/examples_query_spec.rb` 맨 끝에 추가한다. 이 태스크가 무엇을 가능하게 하는지를 고정하는 테스트다 — 엔진이 더 이상 Example을 모른다는 것.

```ruby
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
```

- [ ] **Step 2: 테스트가 실패하는 것을 확인한다**

Run: `bundle exec rspec spec/requests/api/v1/examples_query_spec.rb`

Expected: 두 테스트 모두 FAIL. 파서에 세 상수가 아직 있고, `query_contract`에 `default_sort`가 없다.

- [ ] **Step 3: `examples_controller.rb`의 `query_contract`를 바꾼다**

48-60행을 아래로 바꾼다.

```ruby
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
```

`type: :status`가 `type: :enum`이 된다. `nullable: false`를 지금 넣는 이유는 Task 4다 — keyset cursor가 nullable 정렬을 거부해야 하고, 그 판단 근거가 선언에 있어야 한다.

- [ ] **Step 4: 파서가 계약을 읽게 한다**

`app/lib/jsonapi/query_parser.rb`에서 세 상수(`FILTER_FIELDS` · `SORT_FIELDS` · `MAX_SCORE_INTEGER`)를 지우고, `initialize`를 아래로 바꾼다.

```ruby
    def initialize(scope:, request:, action_params:, contract:, model:)
      @scope = scope
      @request = request
      @action_params = action_params
      @model = model
      @filters = normalize_filters(contract.fetch(:filters))
      @sorts = normalize_sorts(contract.fetch(:sorts))
      @include_contract = contract.fetch(:includes).map(&:to_s).freeze
      @default_sort = contract.fetch(:default_sort).freeze
      @tie_breaker = contract.fetch(:tie_breaker).freeze
      @parsed_filters = []
      @seen_filters = Set.new
      @sort_terms = nil
      @includes = nil
      @page_number = 1
      @page_size = contract.fetch(:default_page_size, Pagination::DEFAULT_PAGE_SIZE)
      @seen_page_parameters = Set.new
    end

    private

    def normalize_filters(declarations)
      declarations.to_h do |name, declaration|
        [
          name.to_s,
          {
            attribute: declaration.fetch(:attribute),
            type: declaration.fetch(:type),
            operators: declaration.fetch(:operators).map(&:to_s).freeze
          }.freeze
        ]
      end.freeze
    end

    def normalize_sorts(declarations)
      declarations.to_h do |name, declaration|
        [
          name.to_s,
          { attribute: declaration.fetch(:attribute), nullable: declaration.fetch(:nullable) }.freeze
        ]
      end.freeze
    end
```

`parse_filter`의 계약 조회를 바꾼다.

```ruby
      declaration = @filters[name]
      invalid_query!("INVALID_FILTER", parameter) unless declaration&.fetch(:operators)&.include?(operator)
```

(`FILTER_FIELDS.key?(name)` 검사는 사라진다 — 이제 `@filters`가 그 역할을 겸한다.)

`parse_scalar`의 타입 분기를 바꾼다.

```ruby
    def parse_scalar(name, raw_value, parameter)
      case @filters.fetch(name).fetch(:type)
      when :string then raw_value
      when :enum then parse_enum(raw_value, parameter)
      when :integer then parse_bounded_integer(raw_value, parameter, INT4_MAX)
      when :bigint then parse_bounded_integer(raw_value, parameter, INT8_MAX)
      when :uuid then parse_uuid(raw_value, parameter)
      when :datetime then parse_datetime(raw_value, parameter)
      else
        raise ArgumentError, "unsupported JSON:API filter type"
      end
    end
```

`parse_status`를 `parse_enum`으로 일반화한다. 이 메서드는 이미 `@model.defined_enums`를 읽고 있었고 이름만 Example을 가리키고 있었다 — 다만 enum 이름을 하드코딩한 `"status"` 자리를 계약이 정하게 바꿔야 한다. 계약의 `attribute`가 곧 enum 이름이다.

```ruby
    def parse_enum(raw_value, parameter)
      enum_name = @filters.fetch(@current_filter_name).fetch(:attribute).to_s
      return raw_value if @model.defined_enums.fetch(enum_name, {}).key?(raw_value)

      invalid_query!("INVALID_FILTER", parameter)
    end
```

`@current_filter_name`은 `parse_scalar`가 진입할 때 세운다 — `parse_scalar`의 첫 줄에 `@current_filter_name = name`을 둔다. 인스턴스 변수를 쓰는 이유는 `parse_enum`의 시그니처를 다른 `parse_*`와 같게 유지하기 위해서다.

정수 범위 상수 둘을 새로 둔다. `type: :integer`가 int4 범위를 함의하고, bigint가 필요한 자원은 `type: :bigint`를 선언한다 — 스펙 §4.2.

```ruby
    INT4_MAX = (2**31) - 1
    INT8_MAX = (2**63) - 1
```

```ruby
    def parse_bounded_integer(raw_value, parameter, maximum)
      invalid_query!("INVALID_FILTER", parameter) unless INTEGER.match?(raw_value)

      value = Integer(raw_value, 10)
      return value if (-maximum - 1..maximum).cover?(value)

      invalid_query!("INVALID_FILTER", parameter)
    rescue ArgumentError
      invalid_query!("INVALID_FILTER", parameter)
    end
```

`parse_sort`의 허용 검사를 바꾼다.

```ruby
        invalid_query!("INVALID_SORT", parameter) unless @sorts.key?(name)
```

`apply_filters`의 컬럼 조회를 바꾼다.

```ruby
    def apply_filters(scope)
      @parsed_filters.reduce(scope) do |relation, filter|
        column = @model.arel_table[@filters.fetch(filter.name).fetch(:attribute)]
        relation.where(filter_predicate(column, filter))
      end
    end
```

`apply_sort`의 하드코딩 기본 정렬을 계약으로 바꾼다.

```ruby
    def apply_sort(scope)
      terms = @sort_terms || default_sort_terms
      terms = [ *terms, tie_breaker_term ] unless terms.any? { |term| term.name == @tie_breaker.fetch(:field) }
      scope.reorder(*terms.map { |term| order_expression(term) })
    end

    def default_sort_terms
      @default_sort.map { |entry| SortTerm.new(entry.fetch(:field), entry.fetch(:direction) == :desc) }
    end

    def tie_breaker_term
      SortTerm.new(@tie_breaker.fetch(:field), @tie_breaker.fetch(:direction) == :desc)
    end

    # tie breaker는 공개 `sorts` 표에 없어도 된다 — `id`가 그 경우다. 표에 없으면
    # 공개 이름을 그대로 컬럼 이름으로 쓴다. 그 값은 사용자 입력이 아니라 컨트롤러의
    # 선언이므로 SQL 식별자 자리에 그대로 들어가도 안전하다.
    def order_expression(term)
      attribute = @sorts.dig(term.name, :attribute) || term.name.to_sym
      column = @model.arel_table[attribute]
      term.descending ? column.desc : column.asc
    end
```

- [ ] **Step 5: 테스트가 통과하는 것을 확인한다**

Run: `bundle exec rspec`

Expected: **전부 통과.** 새 테스트 둘을 포함해 기존 spec이 하나도 깨지지 않아야 한다. 공개 응답이 바뀌지 않는 것이 이 단계의 계약이므로, request spec이 하나라도 깨지면 그것은 버그다.

- [ ] **Step 6: 게이트를 돌린다**

Run: `bundle exec rspec && bundle exec rails rswag:specs:swaggerize && git diff --exit-code -- swagger/v1/swagger.yaml && bundle exec brakeman --no-pager -q && bundle exec rubocop`

Expected: 전부 통과하고 **swagger diff가 비어 있다.** 공개 계약이 바뀌지 않았다는 증거다.

- [ ] **Step 7: 커밋**

```bash
git add app/lib/jsonapi/query_parser.rb app/controllers/api/v1/examples_controller.rb spec/
git commit -m "refactor: move resource knowledge from the query engine to the contract

JsonapiQuery가 모든 자원이 공유하는 concern인데 Example의 컬럼·타입·기본
정렬을 상수로 갖고 있었다. FILTER_FIELDS·SORT_FIELDS·MAX_SCORE_INTEGER를
지우고 query_contract가 그 전부를 선언하게 한다.

parse_status를 parse_enum으로 일반화한다. 이미 model.defined_enums를 읽고
있었고 이름만 Example을 가리키고 있었다.

기본 정렬과 tie breaker를 선언으로 옮긴다 — 파서에 createdAt DESC가 박혀
있으면 두 번째 자원의 name ASC를 낼 수 없다.

공개 응답은 바뀌지 않는다. 기존 request spec 전부와 swagger diff가 빈 것이
그 증거다."
```

---

### Task 3: offset 계약 통일 — probe와 `page[totals]`

**Files:**
- Modify: `app/lib/jsonapi/pagination.rb`
- Modify: `app/lib/jsonapi/query_parser.rb`
- Modify: `app/controllers/concerns/crud_actions.rb:58-67`
- Modify: `spec/swagger_helper.rb:360-370` 부근
- Modify: `Gemfile`
- Test: `spec/requests/api/v1/examples_query_spec.rb`

**Interfaces:**
- Consumes: Task 2의 계약 모양
- Produces: `Jsonapi::QueryResult`의 `total_count`가 `nil`일 수 있다. `links["last"]`도 `nil`일 수 있다.

- [ ] **Step 1: 실패하는 테스트를 쓴다**

`spec/requests/api/v1/examples_query_spec.rb` 맨 끝에 추가한다.

```ruby
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
    expect(document.fetch("links").fetch("last")).to include("page[number]=2")
  end

  it "decides next from a probe row rather than a count" do
    # 요청 크기 +1행을 읽어 next 유무를 판정하고 그 한 행은 응답에서 버린다.
    create_list(:example, 3)

    get "/api/v1/examples?page[size]=2", headers: jsonapi_headers

    document = JSON.parse(response.body)
    expect(document.fetch("data").length).to eq(2)
    expect(document.fetch("links").fetch("next")).to include("page[number]=2")

    get "/api/v1/examples?page[size]=3", headers: jsonapi_headers

    expect(JSON.parse(response.body).fetch("links").fetch("next")).to be_nil
  end

  it "rejects a non-boolean page[totals]" do
    get "/api/v1/examples?page[totals]=yes", headers: jsonapi_headers

    expect(response).to have_http_status(:bad_request)
    expect(JSON.parse(response.body).dig("errors", 0, "code")).to eq("INVALID_PAGE")
  end
```

`create_list(:example, ...)`와 `jsonapi_headers`는 이 파일이 이미 쓰는 헬퍼다. 다르면 그 파일의 기존 방식을 그대로 쓴다 — 새 헬퍼를 만들지 않는다.

- [ ] **Step 2: 테스트가 실패하는 것을 확인한다**

Run: `bundle exec rspec spec/requests/api/v1/examples_query_spec.rb`

Expected: 앞 세 개 FAIL(지금은 `meta`가 항상 있고 `links.last`가 항상 있다), 마지막 하나도 FAIL(`page[totals]`가 아직 알려지지 않은 파라미터라 `INVALID_PAGE`가 나긴 하지만 이유가 다르다 — 통과하더라도 Step 4 이후에 같은 이유로 통과하는지 다시 본다).

- [ ] **Step 3: 파서가 `page[totals]`를 받고 probe를 쓰게 한다**

`app/lib/jsonapi/query_parser.rb`의 `parse_page`를 바꾼다.

```ruby
    def parse_page(parameter, raw_value)
      unless %w[page[number] page[size] page[totals]].include?(parameter) &&
             !@seen_page_parameters.include?(parameter)
        invalid_query!("INVALID_PAGE", parameter)
      end

      @seen_page_parameters << parameter

      if parameter == "page[totals]"
        @totals = parse_boolean(raw_value, parameter)
        return
      end

      value = parse_positive_integer(raw_value, parameter)
      if parameter == "page[number]"
        @page_number = value
      else
        @page_size = [ value, Pagination::MAX_PAGE_SIZE ].min
      end
    end

    def parse_boolean(raw_value, parameter)
      return true if raw_value == "true"
      return false if raw_value == "false"

      invalid_query!("INVALID_PAGE", parameter)
    end
```

`initialize`에 `@totals = false`를 더한다.

`call`을 바꾼다. COUNT를 기본에서 빼고 probe 한 행으로 `next`를 판정한다.

```ruby
    def call
      @raw_pairs = parse_raw_pairs
      if (conflict = Jsonapi::RawQuery.shape_conflict(@raw_pairs))
        invalid_query!(*conflict)
      end
      @raw_pairs.each { |parameter, value| parse_parameter(parameter, value) }
      validate_action_controller_parameters!
      validate_page_offset!

      filtered = apply_filters(@scope)
      total_count = @totals ? filtered.unscope(:order).count : nil
      sorted = apply_sort(filtered)

      # 요청 크기 +1행을 읽어 next 유무를 판정하고 그 한 행은 응답에서 버린다.
      # COUNT 없이 "다음 페이지가 있는가"에 답하는 방법이다.
      probed = Pagination.apply(sorted, page_number: @page_number, page_size: @page_size + 1).to_a
      has_more = probed.length > @page_size
      page_records = has_more ? probed.first(@page_size) : probed

      requested_includes = @includes || []
      page_records = preload_includes(page_records, requested_includes) if requested_includes.any?

      QueryResult.new(
        scope: page_records,
        includes: requested_includes,
        total_count: total_count,
        links: Pagination.links(
          request: @request,
          raw_pairs: @raw_pairs,
          page_number: @page_number,
          page_size: @page_size,
          has_more: has_more,
          total_count: total_count
        ),
        include_requested: !@includes.nil?
      )
    end

    # probe가 relation을 배열로 만들었으므로 `includes`를 relation에 걸 수 없다.
    # 이미 가져온 레코드에 preloader를 직접 물린다 — N+1을 막는 것이 목적이고
    # 그 목적은 relation이든 배열이든 같다.
    def preload_includes(records, paths)
      ActiveRecord::Associations::Preloader.new(
        records: records,
        associations: paths.map(&:to_sym)
      ).call
      records
    end
```

**`scope`가 relation이 아니라 배열이 된다.** `crud_actions.rb:60`의 `result.scope.load`가 배열에서는 동작하지 않으므로 Step 5에서 함께 고친다.

- [ ] **Step 4: `Pagination`이 probe 결과로 링크를 만들게 한다**

`app/lib/jsonapi/pagination.rb`의 `links`를 바꾼다.

```ruby
    # `next`는 probe 행의 유무로 판정한다. `last`는 총 개수를 알아야 만들 수 있으므로
    # `page[totals]=true`로 COUNT를 실행한 요청에서만 나온다 — 그 외에는 nil이다.
    def links(request:, raw_pairs:, page_number:, page_size:, has_more:, total_count:)
      last_page = total_count && [ 1, (total_count + page_size - 1) / page_size ].max
      {
        "self" => page_link(request, raw_pairs, page_number, page_size),
        "first" => page_link(request, raw_pairs, 1, page_size),
        "prev" => page_number > 1 ? page_link(request, raw_pairs, page_number - 1, page_size) : nil,
        "next" => has_more ? page_link(request, raw_pairs, page_number + 1, page_size) : nil,
        "last" => last_page ? page_link(request, raw_pairs, last_page, page_size) : nil
      }
    end
```

- [ ] **Step 5: 렌더러가 `meta`를 조건부로 내게 한다**

`app/controllers/concerns/crud_actions.rb`의 `render_jsonapi_query_index`(58-67행)를 바꾼다.

```ruby
  def render_jsonapi_query_index(scope)
    result = jsonapi_query(scope)
    options = {
      jsonapi: result.scope,
      include: result.includes.map(&:to_sym),
      links: result.links
    }
    # totalCount는 page[totals]=true가 COUNT를 요청했을 때만 나온다. 없는 meta를
    # 빈 해시로 내면 정본과 문서가 갈린다 — 키 자체가 없어야 한다.
    options[:meta] = { totalCount: result.total_count } unless result.total_count.nil?
    render(**options)

    ensure_included_array! if result.include_requested
    response.headers["Content-Type"] = JSONAPI::MEDIA_TYPE
  end
```

`result.scope.load`가 `result.scope`가 된 것에 주의한다 — Task 3부터 `scope`는 이미 로드된 배열이다.

- [ ] **Step 6: swagger 스키마의 `required`를 푼다**

`spec/swagger_helper.rb:350`이 컬렉션 문서 스키마의 필수 멤버를 고정한다.

```ruby
            required: %w[data meta links],
```

`meta`를 뺀다.

```ruby
            required: %w[data links],
```

**`meta` 아래의 `required: [ "totalCount" ]`(365-368행 부근)는 그대로 둔다.** 바꾸는 것은 "`meta`가 반드시 있어야 한다"이지 "`meta`가 있으면 `totalCount`가 있어야 한다"가 아니다. 후자는 여전히 참이다 — `page[totals]=true`로 `meta`가 나오는 경우 그 안에는 언제나 `totalCount`가 있다.

이 한 줄을 빠뜨리면 게이트의 swagger 단계가 아니라 **rspec 단계**가 먼저 깨진다. rswag의 응답 검증이 스키마를 실제 응답에 물리기 때문이다.

- [ ] **Step 7: 기존 기대값을 갱신한다**

Run: `bundle exec rspec`

`meta`와 `links.last`를 무조건 기대하던 spec이 깨진다. 아래 셋이다.

```text
spec/requests/api/v1/examples_query_spec.rb:290
spec/requests/api/v1/examples_query_spec.rb:301
spec/requests/api/v1/examples_query_spec.rb:316
```

**이 목록은 출발점이지 인벤토리가 아니다.** grep으로 만든 것이므로 빠진 자리가 있을 수 있다. 스위트를 돌려 실제로 빨간 것을 전부 고친다. 목록에 없는 파일이 나오면 고치고 보고한다 — 되묻지 않는다.

각 자리에서 판단한다.

- `meta`/`links.last`가 그 테스트의 **주제**이면 요청에 `page[totals]=true`를 더한다.
- 주제가 아니라 부수적으로 단언하고 있으면 그 단언을 지운다.
- **기대값을 없애려고 `meta`를 다시 무조건 내지 않는다.**

- [ ] **Step 8: `kaminari`를 제거한다**

`Gemfile`의 `gem "kaminari"`(71행) 줄을 지운다.

조사 결과 이 gem은 **어디에서도 쓰이지 않는다** — 현재 offset 페이지네이션은 `scope.offset(...).limit(...)`으로 손수 구현되어 있고, `Kaminari` 상수나 `.page` / `.per` 호출이 저장소에 하나도 없다. 지우기 전에 그것을 다시 확인한다.

Run: `grep -rn "Kaminari\|\.page(\|\.per(" app/ lib/ config/ spec/`

Expected: 결과 없음. **하나라도 나오면 지우지 말고 보고한다.**

Run: `bundle install`

`Gemfile.lock`이 갱신된다. 함께 커밋한다.

`spec/configuration/production_dependencies_spec.rb`가 gem 목록을 고정하고 있으면 함께 갱신한다.

- [ ] **Step 9: 전체 게이트**

Run: `bundle exec rspec && bundle exec rails rswag:specs:swaggerize && git diff --exit-code -- swagger/v1/swagger.yaml && bundle exec brakeman --no-pager -q && bundle exec rubocop`

**swagger diff는 이번엔 비지 않는다** — `meta`가 선택이 되었으므로 스키마가 바뀐다. 재생성된 `swagger/v1/swagger.yaml`을 커밋에 포함한다. `git diff --exit-code`는 재생성 후에 돌려 diff가 없는 것(= 커밋된 파일이 최신인 것)을 확인하는 단계이므로, **재생성 → 커밋에 포함 → 다시 확인**의 순서로 진행한다.

- [ ] **Step 10: 커밋**

```bash
git add app/lib/jsonapi/ app/controllers/concerns/crud_actions.rb Gemfile Gemfile.lock spec/ swagger/
git commit -m "feat: make totals opt-in and decide next from a probe row

COUNT를 기본 경로에서 뺀다. 요청 크기 +1행을 읽어 next 유무를 판정하고 그 한
행은 응답에서 버린다. COUNT는 page[totals]=true에서만 실행하고, meta.totalCount와
non-null links.last도 그때만 나온다.

COUNT는 큰 테이블에서 목록 조회보다 비싸질 수 있다. 필요하다고 말한 요청에만
실행한다 — 정본과 같은 계약이다.

kaminari를 제거한다. 어디에서도 쓰이지 않는다 — offset 페이지네이션은
scope.offset(...).limit(...)으로 손수 구현되어 있고 Kaminari 상수나 .page/.per
호출이 저장소에 하나도 없다."
```

---

### Task 4: keyset cursor 신설

**Files:**
- Create: `app/lib/jsonapi/cursor.rb`
- Modify: `app/lib/jsonapi/query_parser.rb`
- Modify: `app/lib/jsonapi/pagination.rb`
- Test: `spec/requests/api/v1/examples_query_spec.rb`

**Interfaces:**
- Consumes: Task 2의 `sorts[].nullable`, Task 3의 probe
- Produces: `Jsonapi::Cursor` — `.encode(signature, values)`, `.decode(raw, signature)`, `.keyset_predicate(model, terms, values, before:)`

- [ ] **Step 1: 실패하는 테스트를 쓴다**

`spec/requests/api/v1/examples_query_spec.rb` 맨 끝에 추가한다.

```ruby
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

  it "rejects a cursor combined with page[number]" do
    get "/api/v1/examples?page[after]=&page[number]=2", headers: jsonapi_headers

    expect(response).to have_http_status(:bad_request)
    expect(JSON.parse(response.body).dig("errors", 0, "code")).to eq("INVALID_PAGE")
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
```

nullable 정렬 거부는 request spec으로 실증할 수 없다 — Example의 정렬 컬럼이 전부 NOT NULL이라 공개 계약에 nullable 정렬이 없기 때문이다. **합성 계약으로 단위 테스트한다.** 새 파일 `spec/lib/jsonapi/cursor_spec.rb`를 만든다.

```ruby
# frozen_string_literal: true

require "rails_helper"

RSpec.describe Jsonapi::Cursor do
  describe ".encode / .decode" do
    it "round-trips values under a matching signature" do
      encoded = described_class.encode("createdAt:desc,id:asc", %w[2026-01-01T00:00:00Z abc])

      expect(described_class.decode(encoded, "createdAt:desc,id:asc")).to eq(%w[2026-01-01T00:00:00Z abc])
    end

    it "rejects a cursor encoded under a different signature" do
      encoded = described_class.encode("createdAt:desc,id:asc", %w[x y])

      expect { described_class.decode(encoded, "title:asc,id:asc") }
        .to raise_error(JsonApiError) { |error| expect(error.code).to eq("INVALID_PAGE") }
    end

    it "rejects a value list whose length does not match the signature" do
      encoded = described_class.encode("createdAt:desc,id:asc", %w[x])

      expect { described_class.decode(encoded, "createdAt:desc,id:asc") }
        .to raise_error(JsonApiError)
    end

    it "rejects a string that is not base64url" do
      expect { described_class.decode("not base64!!", "id:asc") }.to raise_error(JsonApiError)
    end

    it "rejects a payload that is not JSON" do
      encoded = Base64.urlsafe_encode64("not json", padding: false)

      expect { described_class.decode(encoded, "id:asc") }.to raise_error(JsonApiError)
    end
  end
end
```

`JsonApiError`가 `code`를 노출하는지 `app/errors/json_api_error.rb`에서 확인한다. 접근자가 다른 이름이면 그 이름을 쓴다.

nullable 거부는 파서 수준이므로 파서의 합성 계약으로 검증한다. 같은 파일에 더한다.

```ruby
RSpec.describe Jsonapi::QueryParser do
  # 공개 자원 중 nullable 정렬을 여는 것이 하나도 없다 — 정본과 같은 결정이다.
  # 그래서 이 규칙은 실제 계약이 아니라 여기서 만든 계약으로 검증한다. 검증
  # 편의를 위해 공개 계약에 nullable 정렬을 되돌려 놓지 않는다.
  let(:nullable_contract) do
    {
      filters: {},
      sorts: {
        "title" => { attribute: :title, nullable: false },
        "description" => { attribute: :description, nullable: true }
      },
      includes: [],
      default_sort: [ { field: "title", direction: :asc } ],
      tie_breaker: { field: "id", direction: :asc },
      default_page_size: 20
    }
  end

  def parse(query_string, contract)
    request = ActionDispatch::TestRequest.create
    request.set_header("QUERY_STRING", query_string)
    request.set_header("PATH_INFO", "/api/v1/examples")
    described_class.new(
      scope: Example.all,
      request: request,
      action_params: -> { ActionController::Parameters.new },
      contract: contract,
      model: Example
    ).call
  end

  it "rejects cursor mode on a nullable sort" do
    # keyset은 (컬럼, id) > (값, 값) 비교로 자르는데 NULL이 섞이면 비교가 unknown이
    # 되어 행을 조용히 건너뛴다. 조용히 틀린 페이지보다 거절이 낫다.
    expect { parse("sort=description&page[after]=", nullable_contract) }
      .to raise_error(JsonApiError) { |error| expect(error.code).to eq("INVALID_PAGE") }
  end

  it "accepts the same sort in offset mode" do
    # 거부되는 것은 커서 모드뿐이다. 규칙이 정렬 자체를 막는 것으로 넓어지면
    # 이 테스트가 잡는다.
    expect { parse("sort=description&page[number]=1", nullable_contract) }.not_to raise_error
  end

  it "accepts cursor mode on a non-nullable sort" do
    expect { parse("sort=title&page[after]=", nullable_contract) }.not_to raise_error
  end
end
```

`ActionDispatch::TestRequest.create`로 request를 만드는 방식이 이 저장소의 다른 단위 spec과 다르면 그쪽 방식을 따른다.

- [ ] **Step 2: 테스트가 실패하는 것을 확인한다**

Run: `bundle exec rspec spec/lib/jsonapi/cursor_spec.rb spec/requests/api/v1/examples_query_spec.rb`

Expected: FAIL. `Jsonapi::Cursor`가 아직 없고 `page[after]`가 알려지지 않은 파라미터다.

- [ ] **Step 3: `app/lib/jsonapi/cursor.rb`를 만든다**

```ruby
# frozen_string_literal: true

require "base64"
require "json"

module Jsonapi
  # keyset 커서의 인코딩·디코딩과 비교 술어.
  #
  # 커서는 유효 정렬의 컬럼 값들을 담은 opaque 문자열이다. 서명(정렬의 이름과
  # 방향을 이어붙인 문자열)을 함께 담아, 정렬이 달라진 커서를 되돌려받으면
  # 거부한다 — 그러지 않으면 클라이언트가 다른 정렬의 위치로 페이지를 자른다.
  module Cursor
    module_function

    def signature(terms)
      terms.map { |term| "#{term.name}:#{term.descending ? 'desc' : 'asc'}" }.join(",")
    end

    def encode(signature, values)
      Base64.urlsafe_encode64(JSON.generate({ "s" => signature, "v" => values }), padding: false)
    end

    def decode(raw, expected_signature)
      payload = JSON.parse(Base64.urlsafe_decode64(raw))
      raise invalid_cursor unless payload.is_a?(Hash)
      raise invalid_cursor unless payload["s"] == expected_signature

      values = payload["v"]
      raise invalid_cursor unless values.is_a?(Array)
      raise invalid_cursor unless values.length == expected_signature.split(",").length

      values
    rescue ArgumentError, JSON::ParserError
      raise invalid_cursor
    end

    # 커서 값을 문자열로 왕복시킬 수 있는지 본다. 왕복시킬 수 없는 타입이 정렬에
    # 있으면 `next` 링크를 아예 발행할 수 없으므로, 첫 페이지 다음으로 넘어갈
    # 방법이 없는 응답이 나온다 — nullable 거부와 이유가 다르다.
    def encodable?(value)
      case value
      when String, Integer, TrueClass, FalseClass, NilClass then true
      when Time, DateTime, Date then true
      else false
      end
    end

    def serialize(value)
      case value
      when Time, DateTime then value.utc.iso8601(6)
      when Date then value.iso8601
      else value
      end
    end

    # `(a, b) > (x, y)`를 방향별로 펼친다. Arel에 행 비교가 없으므로 사전식으로
    # 전개한다 — 첫 키가 크거나, 같으면서 둘째 키가 크거나, ...
    def keyset_predicate(table, terms, attributes, values, before:)
      comparisons = terms.each_with_index.map do |term, index|
        equals = terms.first(index).each_with_index.map do |prior, prior_index|
          table[attributes.fetch(prior.name)].eq(values[prior_index])
        end
        strict = strict_comparison(table[attributes.fetch(term.name)], term, values[index], before: before)
        equals.reduce(strict) { |combined, equality| equality.and(combined) }
      end

      comparisons.reduce { |combined, comparison| combined.or(comparison) }
    end

    def strict_comparison(column, term, value, before:)
      descending = term.descending
      descending = !descending if before
      descending ? column.lt(value) : column.gt(value)
    end

    def invalid_cursor
      JsonApiError.new(status: 400, code: "INVALID_PAGE", source: { parameter: "page[after]" })
    end
  end
end
```

- [ ] **Step 4: 파서가 커서 파라미터를 받게 한다**

`app/lib/jsonapi/query_parser.rb`의 `parse_page`에 두 파라미터를 더한다.

```ruby
      unless %w[page[number] page[size] page[totals] page[after] page[before]].include?(parameter) &&
             !@seen_page_parameters.include?(parameter)
        invalid_query!("INVALID_PAGE", parameter)
      end

      @seen_page_parameters << parameter

      case parameter
      when "page[totals]"
        @totals = parse_boolean(raw_value, parameter)
        return
      when "page[after]", "page[before]"
        @cursor_raw = raw_value
        @cursor_before = parameter == "page[before]"
        return
      end
```

`initialize`에 `@cursor_raw = nil`과 `@cursor_before = false`를 더한다.

`call`에서 커서 모드와 offset 모드를 가른다.

```ruby
      validate_action_controller_parameters!
      validate_cursor_mode!
      validate_page_offset! if @cursor_raw.nil?
```

```ruby
    # 커서 모드에서 막는 것 셋. 이유가 서로 다르다.
    #
    # 1. page[number]와의 동시 사용 — 두 페이지 개념이 한 요청에 있으면 어느 쪽을
    #    따를지 정할 수 없다.
    # 2. nullable 정렬 — keyset 비교에 NULL이 섞이면 비교가 unknown이 되어 행을
    #    조용히 건너뛴다.
    # 3. 왕복 불가 타입 — next 링크를 만들 수 없어 첫 페이지 다음으로 갈 방법이
    #    없는 응답이 나온다.
    def validate_cursor_mode!
      return if @cursor_raw.nil?

      invalid_query!("INVALID_PAGE", "page[number]") if @seen_page_parameters.include?("page[number]")

      effective_sort_terms.each do |term|
        declaration = @sorts[term.name]
        next if declaration.nil? # tie breaker는 sorts에 없을 수 있다. id는 NOT NULL이다.

        invalid_query!("INVALID_PAGE", cursor_parameter) if declaration.fetch(:nullable)
      end
    end

    def effective_sort_terms
      terms = @sort_terms || default_sort_terms
      return terms if terms.any? { |term| term.name == @tie_breaker.fetch(:field) }

      [ *terms, tie_breaker_term ]
    end

    def cursor_parameter
      @cursor_before ? "page[before]" : "page[after]"
    end
```

`call`의 페이지네이션 분기를 바꾼다.

```ruby
      sorted = apply_sort(filtered)
      if @cursor_raw.nil?
        page_records, has_more = offset_page(sorted)
        links = Pagination.links(
          request: @request, raw_pairs: @raw_pairs, page_number: @page_number,
          page_size: @page_size, has_more: has_more, total_count: total_count
        )
      else
        page_records, has_more = cursor_page(filtered)
        links = Pagination.cursor_links(
          request: @request, raw_pairs: @raw_pairs, page_size: @page_size,
          records: page_records, terms: effective_sort_terms, attributes: sort_attributes,
          has_more: has_more, before: @cursor_before
        )
      end
```

```ruby
    def offset_page(sorted)
      probed = Pagination.apply(sorted, page_number: @page_number, page_size: @page_size + 1).to_a
      has_more = probed.length > @page_size
      [ has_more ? probed.first(@page_size) : probed, has_more ]
    end

    def cursor_page(filtered)
      terms = effective_sort_terms
      attributes = sort_attributes
      scope = filtered

      unless @cursor_raw.empty?
        values = Cursor.decode(@cursor_raw, Cursor.signature(terms))
        scope = scope.where(
          Cursor.keyset_predicate(@model.arel_table, terms, attributes, values, before: @cursor_before)
        )
      end

      order = @cursor_before ? reversed_order(terms, attributes) : forward_order(terms, attributes)
      probed = scope.reorder(*order).limit(@page_size + 1).to_a
      has_more = probed.length > @page_size
      records = has_more ? probed.first(@page_size) : probed
      records = records.reverse if @cursor_before
      [ records, has_more ]
    end

    def sort_attributes
      effective_sort_terms.to_h do |term|
        [ term.name, @sorts.dig(term.name, :attribute) || term.name.to_sym ]
      end
    end

    def forward_order(terms, attributes)
      terms.map do |term|
        column = @model.arel_table[attributes.fetch(term.name)]
        term.descending ? column.desc : column.asc
      end
    end

    def reversed_order(terms, attributes)
      terms.map do |term|
        column = @model.arel_table[attributes.fetch(term.name)]
        term.descending ? column.asc : column.desc
      end
    end
```

- [ ] **Step 5: `Pagination`에 커서 링크를 더한다**

```ruby
    # 커서 링크는 페이지 번호가 아니라 경계 행의 정렬 값으로 만든다. 마지막 행이
    # 다음 페이지의 시작이고 첫 행이 이전 페이지의 끝이다.
    def cursor_links(request:, raw_pairs:, page_size:, records:, terms:, attributes:, has_more:, before:)
      signature = Cursor.signature(terms)
      preserved = raw_pairs.reject { |parameter, _| parameter == "page" || parameter.start_with?("page[") }

      {
        "self" => cursor_link(request, preserved, page_size, nil, nil),
        "first" => cursor_link(request, preserved, page_size, "page[after]", ""),
        "prev" => records.empty? ? nil : cursor_link(
          request, preserved, page_size, "page[before]", boundary_cursor(signature, terms, attributes, records.first)
        ),
        "next" => next_cursor_link(request, preserved, page_size, signature, terms, attributes, records, has_more, before),
        "last" => nil
      }
    end

    def next_cursor_link(request, preserved, page_size, signature, terms, attributes, records, has_more, before)
      return nil if records.empty?
      # page[before]로 읽는 중이면 "다음"은 언제나 존재한다 — 우리가 방금 온 방향이다.
      return cursor_link(request, preserved, page_size, "page[after]",
                         boundary_cursor(signature, terms, attributes, records.last)) if before
      return nil unless has_more

      cursor_link(request, preserved, page_size, "page[after]",
                  boundary_cursor(signature, terms, attributes, records.last))
    end

    def boundary_cursor(signature, terms, attributes, record)
      values = terms.map do |term|
        value = record.public_send(attributes.fetch(term.name))
        raise Cursor.invalid_cursor unless Cursor.encodable?(value)

        Cursor.serialize(value)
      end
      Cursor.encode(signature, values)
    end

    def cursor_link(request, preserved, page_size, parameter, value)
      pairs = [ *preserved, [ "page[size]", page_size.to_s ] ]
      pairs << [ parameter, value ] if parameter
      "#{request.path}?#{URI.encode_www_form(pairs)}"
    end
```

`links.last`는 커서 모드에서 언제나 `nil`이다 — 마지막 페이지의 위치를 알려면 총 개수를 알아야 하고, 커서 모드는 COUNT를 하지 않는다.

- [ ] **Step 6: 테스트가 통과하는 것을 확인한다**

Run: `bundle exec rspec`

Expected: 전부 통과.

커서 순회 테스트가 무한 루프에 빠지면 `next` 링크가 마지막 페이지에서 `nil`이 되지 않는 것이다 — `has_more` 판정을 다시 본다.

- [ ] **Step 7: 전체 게이트**

Run: `bundle exec rspec && bundle exec rails rswag:specs:swaggerize && git diff --exit-code -- swagger/v1/swagger.yaml && bundle exec brakeman --no-pager -q && bundle exec rubocop`

swagger가 `page[after]`·`page[before]` 파라미터를 문서화해야 하면 `spec/swagger_helper.rb`에 더한 뒤 재생성한다.

- [ ] **Step 8: 커밋**

```bash
git add app/lib/jsonapi/ spec/ swagger/
git commit -m "feat: add keyset cursor pagination

page[after]와 page[before]를 연다. 빈 문자열은 각각 컬렉션의 시작과 끝이다.
커서는 유효 정렬의 컬럼 값과 그 정렬의 서명을 담은 opaque 문자열이고,
정렬이 달라진 커서를 되돌려받으면 거부한다.

nullable 정렬에 커서를 쓰면 거부한다 — keyset 비교에 NULL이 섞이면 비교가
unknown이 되어 행을 조용히 건너뛴다. Example의 정렬 컬럼은 전부 NOT NULL이라
실제로는 걸리지 않지만, 규칙이 코드에 있어야 나중에 nullable 정렬을 여는
사람이 막힌다. 합성 계약으로 단위 테스트한다.

왕복시킬 수 없는 타입의 정렬도 거부한다. 이유가 다르다 — nullable은 행을
건너뛰는 문제이고 이쪽은 next 링크를 아예 발행할 수 없는 문제다."
```

---

### Task 5: `categories` · `tags` 읽기 라우트

**Files:**
- Create: `app/controllers/api/v1/example_categories_controller.rb`
- Create: `app/controllers/api/v1/example_tags_controller.rb`
- Modify: `app/serializers/example_category_serializer.rb`
- Modify: `app/serializers/example_tag_serializer.rb`
- Modify: `config/routes.rb:8-25`
- Test: `spec/requests/api/v1/reference_resources_spec.rb` (생성)
- Test: `spec/routing/api/v1/examples_routing_spec.rb` 또는 새 routing spec

**Interfaces:**
- Consumes: Task 2의 `query_contract` 모양
- Produces: `GET /api/v1/categories`, `/api/v1/categories/:id`, `/api/v1/tags`, `/api/v1/tags/:id`

**Rails에서 "읽기 전용"은 `routes.rb`가 정한다.** 스펙 §7이 "`CrudActions`에 읽기 전용 옵션을 추가"하라고 하지만, 그것은 base class가 라우트를 등록하는 FastAPI·NestJS의 이야기다. Rails는 `config/routes.rb`가 라우트를 선언하므로 `only: %i[index show]`가 곧 그 옵션이다. `CrudActions`를 고치지 않는다.

- [ ] **Step 1: 실패하는 테스트를 쓴다**

`spec/requests/api/v1/reference_resources_spec.rb`를 만든다. 이 파일의 factory·헤더 헬퍼는 `spec/requests/api/v1/examples_query_spec.rb`가 쓰는 것을 그대로 따른다 — 새 헬퍼를 만들지 않는다.

이름을 ASCII로 두는 이유는 정렬 기대값이 PostgreSQL의 대조 규칙에 의존하지 않게 하려는 것이다. 한글 이름을 쓰면 DB locale에 따라 순서가 Ruby의 `sort`와 갈릴 수 있다.

```ruby
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
    post "/api/v1/categories", headers: jsonapi_headers, params: "{}"
    expect(response).to have_http_status(:not_found)

    delete "/api/v1/tags/#{ExampleTag.first.id}", headers: jsonapi_headers
    expect(response).to have_http_status(:not_found)
  end

  def get_json(path)
    get path, headers: jsonapi_headers
    JSON.parse(response.body)
  end
end
```

**쓰기 라우트의 상태 코드는 실측한다.** 위 테스트는 404를 기대한다 — Rails는 매치되는 라우트가 없으면 `config/routes.rb:27`의 catch-all이 `route_not_found`로 보낸다. 먼저 돌려 실제 값을 보고 그 값으로 고정한다. 정본(FastAPI)은 405를 낸다. **어느 쪽이든 상관없지만 기대값과 실제가 같아야 하고, 그 값이 무엇인지 보고에 적는다.**

- [ ] **Step 2: 테스트가 실패하는 것을 확인한다**

Run: `bundle exec rspec spec/requests/api/v1/reference_resources_spec.rb`

Expected: FAIL. 라우트가 없어 전부 404다.

- [ ] **Step 3: 두 컨트롤러를 만든다**

`app/controllers/api/v1/example_categories_controller.rb`:

```ruby
# frozen_string_literal: true

module Api
  module V1
    # 분류 자원. 읽기 전용이다.
    #
    # 분류는 서버가 관리하는 참조 데이터다. 쓰기 라우트를 `config/routes.rb`에
    # 선언하지 않는 것이 Rails에서 "읽기 전용"의 전부다 — 라우트가 없으면
    # CrudActions가 물려준 write 액션은 도달할 수 없는 죽은 메서드다.
    #
    # 이 자원이 존재하는 이유는 관계 선택기다. 분류는 Example의 관계로만
    # 노출되어 있어서, 폼이 고를 목록을 가져올 곳이 없었다. `?include=`로 긁는
    # 방식은 불완전하다 — 어떤 Example에도 붙지 않은 분류는 영원히 나타나지 않는다.
    #
    # URL 경로는 `/api/v1/categories`이고 JSON:API type은 `exampleCategories`다.
    # 둘이 다른 것은 의도된 결정이다.
    #
    # `skip_before_action :set_current_user`는 읽기가 공개이기 때문이다. 이 줄은
    # 인증 이식(C2)이 그 콜백 자체를 없앨 때 함께 지워야 한다 — skip_before_action은
    # 없는 콜백을 건너뛰려 하면 ArgumentError를 낸다.
    class ExampleCategoriesController < ApiController
      RESOURCE_UUID = /\A[0-9a-f]{8}(?:-[0-9a-f]{4}){3}-[0-9a-f]{12}\z/i
      private_constant :RESOURCE_UUID

      skip_before_action :set_current_user

      def allowed_includes
        []
      end

      private

      def klass
        ExampleCategory
      end

      def serializer_class
        ExampleCategorySerializer
      end

      def jsonapi_resource_type
        "exampleCategories"
      end

      # 기본 정렬이 `name ASC`인 것은 의도된 것이다. 선택기는 알파벳순이 맞고,
      # Example의 기본 정렬(`createdAt DESC`)과 다른 것은 참조 데이터를 최신순으로
      # 고르지 않기 때문이다.
      #
      # `includes`가 비어 있는 것도 의도된 것이다. `examples` 역참조를 열면
      # Example → category → examples → … 로 순환이 생긴다.
      #
      # **인덱스 판단 — 만들지 않는다.** 근거가 "기존 인덱스로 커버된다"가
      # **아니다.** `name`의 UNIQUE 인덱스가 `name` 순서를 주지만, PostgreSQL은
      # 유니크 제약을 근거로 뒤따르는 정렬 키를 지우지 않으므로 `ORDER BY name, id`
      # 계획에는 incremental sort가 남는다.
      #
      # 그럼에도 `(name, id)` 인덱스를 만들지 않는 이유는 둘이다. `name`이
      # 유니크해서 동점 그룹의 크기가 항상 1이라 그 정렬 단계가 실질적으로 하는
      # 일이 없고, 참조 테이블의 행 수가 작다(분류·라벨 각각 수십 개 규모).
      # `createdAt` 정렬은 유니크가 아니라 동점 그룹 논거가 적용되지 않지만, 행
      # 수가 작아 결론은 같다.
      #
      # "정렬을 여는 변경은 인덱스를 진다"는 규칙이 요구하는 것은 인덱스 자체가
      # 아니라 이 판단의 기록이다.
      def query_contract
        {
          filters: {
            "name" => { attribute: :name, type: :string, operators: %w[exact contains] }
          },
          sorts: {
            "name" => { attribute: :name, nullable: false },
            "createdAt" => { attribute: :created_at, nullable: false }
          },
          includes: [],
          default_sort: [ { field: "name", direction: :asc } ],
          tie_breaker: { field: "id", direction: :asc },
          default_page_size: 20
        }
      end

      def jsonapi_query_mode
        { "index" => :collection, "show" => :none }.fetch(action_name, :none)
      end

      def allowed_relationships
        {}
      end

      def normalized_resource_id(value)
        identifier = value.to_s
        return identifier.downcase if RESOURCE_UUID.match?(identifier)

        raise JsonApiError.new(status: 404, code: "RESOURCE_NOT_FOUND")
      end
    end
  end
end
```

`klass`를 재정의하는 이유는 `CrudActions#klass`가 `controller_name.classify.constantize`로 모델을 찾는데, `example_categories` → `ExampleCategory`가 되어 맞기는 하지만 명시하는 편이 낫기 때문이다. **먼저 확인한다** — `"example_categories".classify`가 `"ExampleCategory"`인지 `bin/rails runner 'puts "example_categories".classify'`로 본다. 맞으면 `klass` 재정의를 지운다.

`app/controllers/api/v1/example_tags_controller.rb`는 같은 모양이다. 클래스명 `ExampleTagsController`, 모델 `ExampleTag`, 시리얼라이저 `ExampleTagSerializer`, type `"exampleTags"`. docstring은 "라벨이 서버가 관리하는 참조 데이터라는 것, 쓰기 라우트를 열지 않는 이유, 이 자원이 존재하는 이유는 `ExampleCategoriesController`와 같다"로 위임하고, 인덱스 판단 주석은 "근거는 `ExampleCategoriesController`와 같다. `name`의 UNIQUE 인덱스가 `name` 순서를 주지만 `ORDER BY name, id`에는 incremental sort가 남는다 — 그럼에도 만들지 않는 이유는 `name`이 유니크해서 동점 그룹이 항상 1이고 라벨 수가 적다는 것이다"로 줄인다.

- [ ] **Step 4: 시리얼라이저에 `self` 링크를 준다**

`app/serializers/example_category_serializer.rb`:

```ruby
# frozen_string_literal: true

class ExampleCategorySerializer < ApplicationSerializer
  set_key_transform :camel_lower
  set_type :example_categories
  set_id { |category| category.id.to_s.downcase }

  attributes :name

  # 이 링크가 가리킬 URL이 실제로 있다 — `GET /api/v1/categories/{id}`.
  # JSON:API type(`exampleCategories`)이 URL 경로(`/api/v1/categories`)와 다른 것은
  # 의도된 결정이다.
  link :self do |category|
    "/api/v1/categories/#{category.id.to_s.downcase}"
  end
end
```

`app/serializers/example_tag_serializer.rb`도 같은 모양이다 — 경로만 `/api/v1/tags/`다.

- [ ] **Step 5: 라우트를 등록한다**

`config/routes.rb`의 `namespace :v1` 블록 안, `examples` 선언 뒤에 더한다.

```ruby
      # 읽기 전용 참조 자원. Rails에서 "읽기 전용"은 여기서 정한다 — only: %i[index show]가
      # 그 전부이고, CrudActions가 물려준 write 액션은 라우트가 없어 도달할 수 없다.
      resources :categories, only: %i[index show], controller: "example_categories"
      resources :tags, only: %i[index show], controller: "example_tags"
```

URL 경로는 `categories`·`tags`이고 컨트롤러는 `ExampleCategoriesController`·`ExampleTagsController`다. `controller:` 옵션이 그 둘을 잇는다.

- [ ] **Step 6: 테스트가 통과하는 것을 확인한다**

Run: `bundle exec rspec spec/requests/api/v1/reference_resources_spec.rb`

Expected: PASS. 쓰기 라우트 테스트의 상태 코드가 기대와 다르면 **실제 값으로 고치고 그 값을 보고에 적는다.**

- [ ] **Step 7: `included[]` 기대값을 갱신한다**

`resourcePath`가 생겼으므로 두 자원이 `included[]`에 실릴 때 `links.self`가 붙는다. **관측 가능한 계약 변경이다.**

Run: `bundle exec rspec`

`included[]`를 통째로 비교하는 단언이 있으면 실패한다. 실패한 자리마다 기대값에 `links`를 더한다.

**있을 수도 없을 수도 있다.** 이 저장소에 그런 단언이 실제로 존재하는지 확인하지 않았다 — B(NestJS)에서 같은 가정을 했다가 그런 단언이 없어 그 단계가 no-op이 되었고, 결과적으로 계약 변경이 아무 고정 없이 실렸다.

그러므로 **결과를 보고에 명시한다.** 깨진 것이 있으면 무엇을 고쳤는지, 없으면 "고칠 것이 없었다"고 적는다. 그리고 없었다면 **`included[]`의 `links.self`를 고정하는 테스트를 하나 새로 쓴다.**

```ruby
  it "gives included reference resources a self link" do
    category = ExampleCategory.create!(name: "guides")
    example = create(:example, category: category)

    get "/api/v1/examples/#{example.id}?include=category", headers: jsonapi_headers

    included = JSON.parse(response.body).fetch("included")
    expect(included.first.dig("links", "self")).to eq("/api/v1/categories/#{category.id.to_s.downcase}")
  end
```

이 테스트는 `spec/requests/api/v1/examples_query_spec.rb`나 `spec/serializers/example_serializer_spec.rb` 중 `include=`를 이미 다루는 쪽에 둔다.

- [ ] **Step 8: 전체 게이트**

Run: `bundle exec rspec && bundle exec rails rswag:specs:swaggerize && git diff --exit-code -- swagger/v1/swagger.yaml && bundle exec brakeman --no-pager -q && bundle exec rubocop`

swagger가 새 라우트 넷을 문서화해야 한다. `spec/swagger_helper.rb`와 rswag의 경로 spec에 두 자원을 더한 뒤 재생성해 커밋에 포함한다. `spec/requests/api_docs_spec.rb`가 문서화된 경로 집합을 고정하고 있으면 함께 갱신한다.

- [ ] **Step 9: 커밋**

```bash
git add app/controllers/api/v1/ app/serializers/ config/routes.rb spec/ swagger/
git commit -m "feat: add read-only categories and tags routes

GET /api/v1/categories와 GET /api/v1/tags를 연다. 분류와 라벨이 Example의
관계로만 노출되어 있어서 폼의 관계 선택기가 고를 목록을 가져올 곳이 없었다.

정렬 기본값은 name ASC다. 참조 데이터는 최신순으로 고르지 않는다.

두 시리얼라이저에 self 링크를 준다. included[]에 실릴 때 그 링크가 붙으므로
기존 응답이 바뀐다 — 기대값을 같은 변경에서 갱신한다.

Rails에서 읽기 전용은 routes.rb의 only: %i[index show]가 전부다. 스펙 7장이
CrudActions에 옵션을 더하라고 하지만 그것은 base class가 라우트를 등록하는
FastAPI·NestJS의 이야기다.

새 인덱스는 만들지 않는다. name의 UNIQUE 인덱스가 name 순서를 주지만
ORDER BY name, id를 완전히 커버하지는 않는다 — PostgreSQL은 유니크 제약을
근거로 뒤따르는 정렬 키를 지우지 않는다. 그래도 만들지 않는 이유는 동점
그룹이 항상 1이고 참조 테이블의 행 수가 작기 때문이며, 그 판단을 정책
선언부 주석에 남겼다."
```

---

## 완료 조건

네 게이트가 전부 통과하고, 아래가 모두 참이다.

- 쿼리 파서에 `FILTER_FIELDS` · `SORT_FIELDS` · `MAX_SCORE_INTEGER`가 없다.
- `query_contract`가 컬럼·타입·기본 정렬·tie breaker·기본 페이지 크기를 전부 선언한다.
- `page[totals]` 없이 목록을 부르면 `meta` 키가 없고 `links.last`가 `null`이다.
- `page[totals]=true`면 `meta.totalCount`와 non-null `links.last`가 나온다.
- `next`가 COUNT가 아니라 probe 행으로 판정된다.
- `page[after]=`로 시작해 `links.next`를 따라가면 컬렉션 전체를 정확히 한 번씩 지난다.
- `page[after]`와 `page[number]`를 함께 보내면 `INVALID_PAGE`다.
- 정렬이 달라진 커서를 되돌려보내면 `INVALID_PAGE`다.
- nullable 정렬에 커서를 쓰면 `INVALID_PAGE`다 (합성 계약으로 검증).
- `kaminari`가 `Gemfile`에 없다.
- `GET /api/v1/categories`와 `GET /api/v1/tags`가 `name` 오름차순 목록을 낸다.
- 두 자원의 `type`이 `exampleCategories` · `exampleTags`다.
- 두 경로에 쓰기 라우트가 없다.
- `GET /api/v1/examples?include=category`의 `included[]`에 `links.self`가 있다.
- `swagger/v1/swagger.yaml`이 재생성된 결과와 같다.

**마지막 검증은 정본과의 응답 대조다.** 스펙 §9의 마지막 행이고, 이 계획의 진짜 완료 조건이다. 위 항목들은 그 대조가 실패했을 때 어디를 볼지 좁히기 위한 것이다.

## 이 계획이 다루지 않는 것

**단계 3(인증 이식).** 별도 계획(C2)이 다룬다. 이 계획이 만드는 두 컨트롤러의 `skip_before_action :set_current_user` 두 줄을 C2가 함께 지워야 한다 — C2 계획의 파일 목록에 이 항목을 넣는다.

**정본과의 대조 스크립트.** 스펙 §10의 리스크 표가 "같은 요청 집합을 두 스택에 던져 문서를 비교하는 스크립트를 단계 2에서 만들어 이후 단계마다 재사용한다"고 한다. 만들지 않는다 — A(FastAPI)와 B(NestJS)에서 같은 판단을 했고 이유가 같다. 세 백엔드가 공유하는 도구인데 어디에 둘지가 이 계획 혼자 정할 문제가 아니고, Next.js 스펙 10.4의 3-백엔드 매트릭스 E2E가 그 자동화의 자연스러운 자리다. 세 백엔드가 모두 통일된 뒤 별도 작업으로 만든다. 그때까지 위 완료 조건의 마지막 항목은 수작업 대조로 남는다.

## 정본과 의도적으로 다른 자리

이 브랜치의 최종 리뷰에서 실제로 응답을 대조해 찾아낸, 세 백엔드가 합의하지 않고 남겨 둔 차이다. 프런트엔드 단계가 이걸 다시 발견하지 않도록 여기 적어 둔다.

1. **참조 자원에 쓰기 요청** — FastAPI 405/`HTTP_ERROR`, NestJS 404/`HTTP_ERROR`, Rails 404/`RESOURCE_NOT_FOUND`. 프레임워크 라우팅 방식 차이. E2E는 "쓰기가 열려 있지 않다"만 단언하고 status·code는 백엔드별로 기대한다.
2. **커서 문자열** — 세 백엔드의 페이로드 형식이 전부 다르다. JSON:API가 opaque로 정의한 값이므로 맞추지 않는다. E2E는 문자열이 아니라 **동작**(링크를 따라가면 정확히 한 번씩 지나는가, 정렬이 다른 커서는 거부되는가)을 비교한다.
3. **`links.*`의 퍼센트 인코딩** — Ruby의 `URI.encode_www_form`은 `*`를 유지하고 `~`를 인코딩하며 Python은 반대다. 디코딩 값은 같고 Ruby 쪽이 form-urlencoded 스펙을 따른다. E2E는 raw 문자열이 아니라 **디코딩된 쿼리 쌍**으로 비교하되 **순서는 비교한다**.
4. **단건 조회의 최상위 `links.self`** — Rails는 `request.base_url + request.fullpath`(API 전체에서 유일한 절대 URL)를 내고 정본은 최상위 `links`를 내지 않는다. JSON:API가 최상위 `self`를 "현재 응답 문서를 생성한 링크"로 정의하므로 Rails 동작은 규격에 맞고, 정본이 선택 멤버를 생략할 뿐이다. 같은 이유로 `show`의 `included: []` 누락도 여기 속한다.
5. **연관 자원 to-many URL** (`/examples/{id}/tags`) — FastAPI와 NestJS는 페이지네이션 `links`와 `meta.totalCount`를 무조건 내고 `page[number]`/`page[size]`를 받는다. Rails는 셋 다 없고 `page[size]`를 `INVALID_QUERY_PARAMETER`로 거부한다. **3중 2가 Rails와 다르므로 읽기 표면에 남은 가장 큰 구멍이고, 이 스펙의 네 단계 어디에도 없어 별도 작업이 필요하다.**

**새 자원을 열 때 정본의 대응 테스트 파일을 나란히 읽는다.** 이번 브랜치에서 위 5번과 `include` 거부가 정확히 그 방법으로 발견됐고, 그 전에 다섯 번의 태스크 리뷰를 통과했다.
