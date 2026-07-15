# Rails Example API 대칭화 구현 계획

> **에이전트 작업자 필수 하위 스킬:** 구현 시 `superpowers:subagent-driven-development`(권장) 또는 `superpowers:executing-plans`를 사용해 이 계획을 작업 단위로 실행한다. 진행 상태는 체크박스(`- [ ]`)로 추적한다.

**목표:** Blog/Email 예제를 제거하고 `template-python-fastapi`와 동일한 공개 `Example` JSON:API 계약, 외부 Auth 기반 쓰기 보호, 개발용 Docker Compose를 제공한다.

**아키텍처:** `Example`·`ExampleCategory`·`ExampleTag`·`ExampleTagging`이 저장 모델을 담당하고, `ExamplesController`는 공통 `CrudActions`에 리소스 정책만 선언한다. JSON:API 협상·오류·조회 해석·관계 변경은 작은 controller concern으로 분리하되 트랜잭션 경계는 `CrudActions`가 소유한다. 읽기는 공개하고 모든 쓰기는 기존 `session_web` 외부 Auth 검증을 통과해야 한다.

**기술 스택:** Ruby 3.4.8, Rails 8.1.2, PostgreSQL 18, jsonapi-serializer, RSpec, SimpleCov, Sidekiq/Redis, Docker Compose, WireMock

## 전역 제약조건

- 승인된 설계 문서 `docs/superpowers/specs/2026-07-15-example-api-parity-design.md`의 공개 경로, 오류 code, 필터·정렬·include 허용 목록을 변경하지 않는다.
- 구현은 각 작업의 실패 테스트부터 시작하고, 해당 테스트가 예상 이유로 실패하는 것을 확인한 뒤 최소 코드를 작성한다.
- 기존 외부 Auth 서비스, ActiveStorage, Sidekiq, rack-attack, lograge, rswag는 유지한다.
- Category와 Tag에 독립 CRUD route 또는 canonical self link를 추가하지 않는다.
- 응답 키는 JSON:API camelCase 계약(`createdAt`, `updatedAt`, `totalCount`)을 사용하고 Rails 내부 속성은 snake_case로 유지한다.
- DB 및 관계 변경과 최종 직렬화는 같은 트랜잭션 안에서 끝내 rollback 검증을 가능하게 한다.
- 각 커밋 전 변경 범위 테스트를 실행하고, 마지막 작업에서 전체 RSpec, RuboCop, Brakeman, Compose 검증, production image build를 실행한다.

## 계획 실행용 격리 테스트 데이터베이스

작업 1을 시작하기 전에 아래 명령을 한 셸에서 실행하고, 모든 RSpec 및 Rails DB 명령에 같은 환경 변수를 유지한다. 현재 `config/database.yml`이 요구하는 PostgreSQL 환경 변수를 명시하고 임의의 호스트 포트를 사용하므로 로컬 DB나 다른 Compose 프로젝트와 충돌하지 않는다.

```bash
export RAILS_PLAN_DB_CONTAINER="template-ruby-rails-plan-db-$$"
docker run -d --rm --name "$RAILS_PLAN_DB_CONTAINER" \
  --health-cmd="pg_isready -U postgres -d template_test" \
  --health-interval=1s --health-timeout=5s --health-retries=60 \
  -e POSTGRES_USER=postgres \
  -e POSTGRES_PASSWORD=postgres \
  -e POSTGRES_DB=template_test \
  -p 127.0.0.1::5432 \
  postgres:18-alpine
until [ "$(docker inspect --format '{{.State.Health.Status}}' "$RAILS_PLAN_DB_CONTAINER")" = "healthy" ]; do sleep 1; done
RAILS_PLAN_DB_ENDPOINT="$(docker port "$RAILS_PLAN_DB_CONTAINER" 5432/tcp)"
export DATABASE_HOST=127.0.0.1
export DATABASE_PORT="${RAILS_PLAN_DB_ENDPOINT##*:}"
export TEST_DATABASE_USERNAME=postgres
export TEST_DATABASE_PASSWORD=postgres
export TEST_DATABASE_NAME=template_test
export DEV_DATABASE_USERNAME=postgres
export DEV_DATABASE_PASSWORD=postgres
export DEV_DATABASE_NAME=template_development
RAILS_ENV=test bundle exec rails runner 'abort unless ActiveRecord::Base.connection.select_value("SELECT 1") == 1'
```

예상: runner가 exit 0이고 격리된 `template_test` 연결이 확인된다. 작업 12의 최종 정리 전까지 컨테이너를 유지한다.

---

### 작업 1: 커버리지 게이트와 JSON:API 요청 테스트 기반 추가

**파일:**
- 수정: `Gemfile`
- 수정: `Gemfile.lock`
- 수정: `spec/rails_helper.rb`
- 생성: `spec/support/jsonapi_request_helper.rb`
- 생성: `spec/configuration/simplecov_spec.rb`

- [ ] **1.1 실패 테스트 작성**

`spec/configuration/simplecov_spec.rb`는 `spec/rails_helper.rb` source를 읽어 기본 표현식이 정확히 `ENV.fetch("COVERAGE_MINIMUM", "80").to_f`인지, filter 선언이 승인된 세 경로와 정확히 일치하는지 검증한다. runtime에서는 `SimpleCov.minimum_coverage`가 현재 `ENV.fetch("COVERAGE_MINIMUM", "80").to_f`와 일치하는지 검증해 좁은 실행의 override와 기본 80 계약을 모두 모순 없이 고정한다. `spec/support/jsonapi_request_helper.rb`에는 다음 고정 helper를 선언한다.

```ruby
module JsonapiRequestHelper
  JSONAPI_MEDIA_TYPE = "application/vnd.api+json"

  def jsonapi_headers(language: "ko", cookie: nil)
    headers = {
      "ACCEPT" => JSONAPI_MEDIA_TYPE,
      "CONTENT_TYPE" => JSONAPI_MEDIA_TYPE,
      "ACCEPT_LANGUAGE" => language
    }
    headers["COOKIE"] = "session_web=#{cookie}" if cookie
    headers
  end

  def parsed_body
    JSON.parse(response.body)
  end
end
```

- [ ] **1.2 실패 확인**

실행: `COVERAGE_MINIMUM=0 bundle exec rspec spec/configuration/simplecov_spec.rb`

예상: `SimpleCov`가 설치·설정되지 않아 실패한다.

- [ ] **1.3 최소 구현**

`Gemfile`의 test group에 `simplecov`를 추가하고 lockfile을 갱신한다. `spec/rails_helper.rb`에서 Rails environment를 require하기 전에 SimpleCov를 시작한다. `track_files "app/**/*.rb"`, `minimum_coverage ENV.fetch("COVERAGE_MINIMUM", "80").to_f`, 제외 경로는 아래만 사용한다. 기본 전체 suite gate는 80이고, 작업 중 좁은 실패/통과 확인에만 `COVERAGE_MINIMUM=0`을 명시한다.

```ruby
add_filter "app/channels/application_cable/"
add_filter "app/helpers/application_helper.rb"
add_filter "app/mailers/application_mailer.rb"
```

RSpec에 `JsonapiRequestHelper`를 request spec용으로 include한다.

- [ ] **1.4 통과 확인**

실행: `COVERAGE_MINIMUM=0 bundle exec rspec spec/configuration/simplecov_spec.rb`

예상: PASS. 이 시점의 전체 suite는 아직 80% 미만일 수 있으므로 마지막 작업 전까지 전체 gate 실패를 허용한다.

- [ ] **1.5 커밋**

```bash
git add Gemfile Gemfile.lock spec/rails_helper.rb spec/support/jsonapi_request_helper.rb spec/configuration/simplecov_spec.rb
git commit -m "test: add Rails coverage contract"
```

### 작업 2: Blog/Email 초기 스키마를 Example 스키마로 교체

**파일:**
- 삭제: `db/migrate/20260201000000_create_blog_and_email_tables.rb`
- 생성: `db/migrate/20260201000000_create_example_schema.rb`
- 수정: `db/schema.rb`
- 수정: `db/seeds.rb`
- 생성: `spec/migrations/create_example_schema_spec.rb`

- [ ] **2.1 실패 테스트 작성**

마이그레이션 spec에서 새 database connection에 초기 마이그레이션을 적용해 다음을 검증한다.

- 네 테이블 `examples`, `example_categories`, `example_tags`, `example_taggings` 존재
- UUID 기본 키, `examples.category_id` nullable FK `ON DELETE SET NULL`
- `example_taggings` 복합 PK와 양쪽 cascade FK
- `title` 최대 200, `status` CHECK, `score` 0..100 CHECK
- category/tag name unique index
- Example, Category, Tag 모두 `created_at`, `updated_at` non-null timestamps
- `blog_*`, `email_templates` 테이블 부재
- `down` 후 네 테이블 부재

- [ ] **2.2 실패 확인**

실행: `COVERAGE_MINIMUM=0 bundle exec rspec spec/migrations/create_example_schema_spec.rb`

예상: Example 테이블과 새 migration class가 없어 실패한다.

- [ ] **2.3 최소 구현**

기존 초기 migration을 같은 timestamp의 `CreateExampleSchema`로 교체한다. 모든 PK는 `id: :uuid, default: -> { "gen_random_uuid()" }`를 사용하고 Example, Category, Tag에 non-null timestamps를 추가한다. `examples.status` 기본값은 `draft`, `score` 기본값은 0으로 하고 PostgreSQL CHECK를 추가한다. `db/seeds.rb`는 `General`, `Ruby`, `API` category/tag를 `find_or_create_by!`로 생성해 반복 실행 가능하게 한다.

같은 migration version을 교체하므로 작업 1에서 기존 Blog/Email migration version이 기록된 test DB를 포함해 계획용 development/test DB를 모두 명시적으로 reset한 뒤 schema를 재생성한다. 이 명령은 위에서 만든 격리 PostgreSQL 컨테이너만 대상으로 한다.

실행: `RAILS_ENV=development bin/rails db:drop db:create db:migrate`

예상: development DB migration 성공, `db/schema.rb`에 Example 테이블만 도메인 테이블로 기록된다.

실행: `RAILS_ENV=test bin/rails db:drop db:create db:migrate`

예상: 기존 `schema_migrations` 기록이 제거되고 교체한 `20260201000000` migration이 test DB에 다시 적용되어 Example 테이블이 존재한다.

- [ ] **2.4 통과 확인**

실행: `COVERAGE_MINIMUM=0 bundle exec rspec spec/migrations/create_example_schema_spec.rb`

예상: PASS.

- [ ] **2.5 커밋**

```bash
git add db/migrate db/schema.rb db/seeds.rb spec/migrations/create_example_schema_spec.rb
git commit -m "feat: replace sample schema with examples"
```

### 작업 3: Example 저장 모델과 관계 규칙 구현

**파일:**
- 생성: `app/models/example.rb`
- 생성: `app/models/example_category.rb`
- 생성: `app/models/example_tag.rb`
- 생성: `app/models/example_tagging.rb`
- 생성: `spec/factories/examples.rb`
- 생성: `spec/models/example_spec.rb`
- 생성: `spec/models/example_relationships_spec.rb`

- [ ] **3.1 실패 테스트 작성**

model spec에 다음 examples를 명시한다.

- title blank/201자 거부, description nullable
- status `draft`, `active`, `archived` 저장 및 그 외 값 거부
- score 0과 100 허용, -1과 101 거부, 정수가 아닌 값 거부
- category optional, category 삭제 시 null
- example 삭제 시 tagging 삭제, tag 삭제 시 tagging 삭제
- 같은 category/tag name 및 같은 example-tag pair 중복 거부
- factory가 UUID와 기본값을 가진 유효한 객체 생성

- [ ] **3.2 실패 확인**

실행: `COVERAGE_MINIMUM=0 bundle exec rspec spec/models/example_spec.rb spec/models/example_relationships_spec.rb`

예상: model constants가 없어 실패한다.

- [ ] **3.3 최소 구현**

`Example`에 string-backed enum과 validation을 선언한다.

```ruby
enum :status, { draft: "draft", active: "active", archived: "archived" }, prefix: true
belongs_to :category, class_name: "ExampleCategory", optional: true
has_many :example_taggings, dependent: :destroy
has_many :tags, through: :example_taggings, source: :example_tag
validates :title, presence: true, length: { maximum: 200 }
validates :score, numericality: { only_integer: true, in: 0..100 }
```

Category/Tag는 name presence·uniqueness를 갖고, Tagging은 두 association과 pair uniqueness를 갖는다. factory는 category 및 tag traits를 제공하되 암묵적으로 관계를 생성하지 않는다.

- [ ] **3.4 통과 확인**

실행: `COVERAGE_MINIMUM=0 bundle exec rspec spec/models/example_spec.rb spec/models/example_relationships_spec.rb`

예상: PASS.

- [ ] **3.5 커밋**

```bash
git add app/models/example*.rb spec/factories/examples.rb spec/models/example*.rb
git commit -m "feat: add Example domain models"
```

### 작업 4: JSON:API serializer와 canonical link 고정

**파일:**
- 생성: `app/serializers/example_serializer.rb`
- 생성: `app/serializers/example_category_serializer.rb`
- 생성: `app/serializers/example_tag_serializer.rb`
- 생성: `spec/serializers/example_serializer_spec.rb`

- [ ] **4.1 실패 테스트 작성**

serializer spec은 기본 응답과 `include: [:category, :tags]` 응답을 파싱해 다음을 검증한다.

- type `examples`, lowercase canonical UUID id
- attributes가 정확히 `title`, `description`, `status`, `score`, `createdAt`, `updatedAt`
- relationships 순서 `category`, `tags`와 linkage type `exampleCategories`, `exampleTags`
- Example self `/api/v1/examples/{id}`
- relationship self/related link
- included category/tag에는 `name`만 있고 self link가 없음
- `include=`일 때 `included: []`

- [ ] **4.2 실패 확인**

실행: `COVERAGE_MINIMUM=0 bundle exec rspec spec/serializers/example_serializer_spec.rb`

예상: serializer constants가 없어 실패한다.

- [ ] **4.3 최소 구현**

serializer에서 `set_type`, `set_id`, 명시적 key transform과 link blocks를 사용한다. `ExampleSerializer` 이외 serializer는 self link를 선언하지 않는다. 관계 link는 object id를 `String#downcase`한 값으로 구성한다.

- [ ] **4.4 통과 확인**

실행: `COVERAGE_MINIMUM=0 bundle exec rspec spec/serializers/example_serializer_spec.rb`

예상: PASS.

- [ ] **4.5 커밋**

```bash
git add app/serializers/example*.rb spec/serializers/example_serializer_spec.rb
git commit -m "feat: serialize Example JSON API resources"
```

### 작업 5: 안정적인 JSON:API 오류와 미디어 타입 협상 구현

**파일:**
- 생성: `app/errors/json_api_error.rb`
- 생성: `app/controllers/concerns/jsonapi_errors.rb`
- 생성: `app/controllers/concerns/jsonapi_negotiation.rb`
- 생성: `config/locales/jsonapi.ko.yml`
- 생성: `config/locales/jsonapi.en.yml`
- 수정: `app/controllers/application_controller.rb`
- 수정: `app/controllers/api_controller.rb`
- 수정: `config/routes.rb`
- 수정: `spec/support/jsonapi_errors_patch.rb`
- 생성: `spec/requests/api/v1/jsonapi_negotiation_spec.rb`
- 생성: `spec/requests/api/v1/jsonapi_errors_spec.rb`

- [ ] **5.1 실패 테스트 작성**

request specs에 다음 status/code/source를 고정한다.

- 호환되지 않는 Accept: `406 NOT_ACCEPTABLE`, `source.parameter=Accept`
- body가 있는 write의 잘못된 Content-Type: `415 UNSUPPORTED_MEDIA_TYPE`
- malformed JSON 및 data 누락: `400 INVALID_JSONAPI_DOCUMENT`
- unknown route/action: `404 RESOURCE_NOT_FOUND`
- ko 기본과 `Accept-Language: en` 번역
- validation pointer `/data/attributes/title`
- 강제 StandardError: `500 INTERNAL_SERVER_ERROR`, SQL/stack/message 비노출
- 모든 오류 response Content-Type `application/vnd.api+json`
- locale catalog의 code가 `NOT_ACCEPTABLE`, `UNSUPPORTED_MEDIA_TYPE`, `INVALID_JSONAPI_DOCUMENT`, `INVALID_QUERY_PARAMETER`, `INVALID_FILTER`, `INVALID_SORT`, `INVALID_INCLUDE`, `INVALID_PAGE`, `RESOURCE_NOT_FOUND`, `RELATIONSHIP_RESOURCE_NOT_FOUND`, `TYPE_MISMATCH`, `ID_MISMATCH`, `CLIENT_GENERATED_ID_UNSUPPORTED`, `RESOURCE_CONFLICT`, `VALIDATION_ERROR`, `INTERNAL_SERVER_ERROR`, `HTTP_ERROR`, `AUTHENTICATION_REQUIRED`, `FORBIDDEN`, `AUTH_SERVICE_UNAVAILABLE`와 정확히 일치

- [ ] **5.2 실패 확인**

실행: `COVERAGE_MINIMUM=0 bundle exec rspec spec/requests/api/v1/jsonapi_negotiation_spec.rb spec/requests/api/v1/jsonapi_errors_spec.rb`

예상: 현재 오류 형식에 code/source가 없고 미디어 타입 검사가 없어 실패한다.

- [ ] **5.3 최소 구현**

`JsonApiError`는 `status`, `code`, `source`, interpolation context만 보유하고 title/detail은 I18n catalog에서 조회한다. `JsonapiErrors`는 `rescue_from`으로 parse error, record not found, record not unique, validation, StandardError를 mapping한다. Rails route recognition 실패는 controller rescue에 도달하지 않으므로 `config/routes.rb` 마지막에 `match "*unmatched", to: "application#route_not_found", via: :all`을 두고 `ApplicationController#route_not_found`가 `RESOURCE_NOT_FOUND`를 raise하도록 한다. `JsonapiNegotiation`은 parameter 없는 JSON:API media type과 허용 JSON:API ext/profile parameter만 수락하고, body가 실제 존재하는 write에만 Content-Type을 요구한다.

`ApiController#set_current_user`의 Sentry context 코드는 제거하고, 인증 서비스 오류는 `AUTH_SERVICE_UNAVAILABLE`로 mapping한다. 기존 monkey patch는 새 rescue 구조와 충돌하지 않게 삭제하거나 새 module include만 담당하도록 축소한다.

- [ ] **5.4 통과 확인**

실행: `COVERAGE_MINIMUM=0 bundle exec rspec spec/requests/api/v1/jsonapi_negotiation_spec.rb spec/requests/api/v1/jsonapi_errors_spec.rb`

예상: PASS.

- [ ] **5.5 커밋**

```bash
git add app/errors/json_api_error.rb app/controllers/application_controller.rb app/controllers/api_controller.rb app/controllers/concerns/jsonapi_errors.rb app/controllers/concerns/jsonapi_negotiation.rb config/routes.rb config/locales/jsonapi.ko.yml config/locales/jsonapi.en.yml spec/support/jsonapi_errors_patch.rb spec/requests/api/v1/jsonapi_negotiation_spec.rb spec/requests/api/v1/jsonapi_errors_spec.rb
git commit -m "feat: enforce JSON API error and media contracts"
```

### 작업 6: 허용 목록 기반 조회 parser 구현

**파일:**
- 생성: `app/controllers/concerns/jsonapi_query.rb`
- 수정: `app/controllers/concerns/crud_actions.rb`
- 생성: `spec/requests/api/v1/examples_query_spec.rb`

- [ ] **6.1 실패 테스트 작성**

목록 request spec에 승인된 모든 조합을 table-driven examples로 작성한다.

- title exact/contains
- status exact/in
- score exact/gt/gte/lt/lte/in
- category.id exact/in/isNull
- createdAt exact/gt/gte/lt/lte
- sort 다섯 필드와 descending, 기본 `-createdAt,id`, 사용자 sort 뒤 id tie-breaker
- include category/tags, 중복 include 제거, 빈 include의 `included: []`
- page 기본 20, max 100, `meta.totalCount`, self/first/prev/next/last
- unknown field/operator/sort/include/page key, 잘못된 숫자·날짜·boolean, 중복 단일 parameter는 각각 `INVALID_FILTER`, `INVALID_SORT`, `INVALID_INCLUDE`, `INVALID_PAGE`, `INVALID_QUERY_PARAMETER`

- [ ] **6.2 실패 확인**

실행: `COVERAGE_MINIMUM=0 bundle exec rspec spec/requests/api/v1/examples_query_spec.rb`

예상: Examples route/controller가 없고 기존 Ransack 동작이 계약을 충족하지 못해 실패한다.

- [ ] **6.3 최소 구현**

`JsonapiQuery`가 raw query string과 `ActionController::Parameters`를 함께 검증한다. controller가 아래 정책 hash를 반환하도록 한다.

```ruby
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
```

필드명을 안전한 Arel column/association mapping으로 변환하고 사용자 문자열을 SQL fragment로 직접 삽입하지 않는다. pagination link는 기존 query를 보존하며 없는 prev/next는 `null`이다. `CrudActions#index`는 parser가 반환한 scope, include, pagination만 직렬화한다.

- [ ] **6.4 통과 확인**

실행: `COVERAGE_MINIMUM=0 bundle exec rspec spec/requests/api/v1/examples_query_spec.rb`

예상: PASS.

- [ ] **6.5 커밋**

```bash
git add app/controllers/concerns/jsonapi_query.rb app/controllers/concerns/crud_actions.rb spec/requests/api/v1/examples_query_spec.rb
git commit -m "feat: add strict Example query contract"
```

### 작업 7: Example CRUD와 원자적 PUT upsert 구현

**파일:**
- 생성: `app/controllers/api/v1/examples_controller.rb`
- 수정: `app/controllers/concerns/crud_actions.rb`
- 수정: `config/routes.rb`
- 생성: `spec/requests/api/v1/examples_crud_spec.rb`
- 생성: `spec/requests/api/v1/examples_upsert_spec.rb`
- 생성: `spec/routing/api/v1/examples_routing_spec.rb`

- [ ] **7.1 실패 테스트 작성**

CRUD spec은 GET index/show, POST 201, PATCH 200, DELETE 204와 생성 `Location == data.links.self`를 검증한다. 문서 검증에는 type mismatch, URL/body id mismatch, POST client id, conflict, attributes-only 및 relationships-only PATCH, 404를 포함한다.

routing spec은 기본 6개 method-path-action mapping을 정확히 고정한다: GET collection→`index`, POST collection→`create`, GET member→`show`, PATCH member→`update`, PUT member→`upsert`, DELETE member→`destroy`. Rails form용 `new`/`edit` action route가 생성되지 않았음을 route table에서 확인한다. `/examples/new`는 동적 member show의 `id="new"`로 인식될 수 있으므로 `new` action 부재를 확인하고, `/examples/:id/edit`는 최종 catch-all로 가는지 확인한다.

upsert spec은 다음을 검증한다.

- 없는 UUID PUT: 201 + 요청 UUID로 생성
- 있는 UUID PUT: 200 + 전체 attribute 교체
- 생략한 description/category는 null, tags는 빈 목록
- 같은 UUID 동시 PUT 두 개가 중복 row 없이 각각 200/201 중 하나로 성공
- after hook 또는 serializer를 강제로 실패시키면 모델/관계 모두 rollback
- UUID의 대문자 입력도 Location/self는 lowercase canonical 값

동시성 example group은 `self.use_transactional_tests = false`로 선언한다. `DatabaseCleaner.clean_with(:truncation)`을 before/after에서 실행하고, 경쟁 전 setup row는 commit된 상태로 만든다. 각 thread는 고유 `ActionDispatch::Integration::Session`과 Active Record connection을 사용하며 barrier 이후 실제 PUT 요청을 동시에 보낸다. thread 종료 뒤 연결을 반환하고 truncation으로 정리해 transactional fixture가 다른 connection에서 데이터를 숨기거나 cleanup을 누락하지 않게 한다.

- [ ] **7.2 실패 확인**

실행: `COVERAGE_MINIMUM=0 bundle exec rspec spec/requests/api/v1/examples_crud_spec.rb spec/requests/api/v1/examples_upsert_spec.rb spec/routing/api/v1/examples_routing_spec.rb`

예상: route/action이 없어 실패한다.

- [ ] **7.3 최소 구현**

routes의 최종 `*unmatched` catch-all보다 위에 기본 action을 `index`, `show`, `create`, `destroy`로 제한하고 PATCH와 PUT을 서로 다른 action으로 명시한다.

```ruby
resources :examples, only: %i[index show create destroy]
patch "examples/:id", to: "examples#update"
put "examples/:id", to: "examples#upsert"
```

`ExamplesController`는 serializer, model params, query contract, allowed relationships를 선언한다. `CrudActions`는 create/update/upsert에서 다음 순서를 지킨다.

1. JSON:API document/type/id 검증
2. transaction 시작
3. PUT이면 `pg_advisory_xact_lock(hashtextextended(normalized_uuid, 0))`
4. row 조회 또는 build, 관계 포함 전체 assignment
5. save와 hook 실행
6. transaction 안에서 serializer output 생성
7. commit 후 이미 생성한 payload와 Location render

POST client id는 `CLIENT_GENERATED_ID_UNSUPPORTED`, PUT URL/body mismatch는 `ID_MISMATCH`, unique race는 `RESOURCE_CONFLICT`로 mapping한다.

- [ ] **7.4 통과 확인**

실행: `COVERAGE_MINIMUM=0 bundle exec rspec spec/requests/api/v1/examples_crud_spec.rb spec/requests/api/v1/examples_upsert_spec.rb spec/routing/api/v1/examples_routing_spec.rb`

예상: PASS.

- [ ] **7.5 커밋**

```bash
git add app/controllers/api/v1/examples_controller.rb app/controllers/concerns/crud_actions.rb config/routes.rb spec/requests/api/v1/examples_crud_spec.rb spec/requests/api/v1/examples_upsert_spec.rb spec/routing/api/v1/examples_routing_spec.rb
git commit -m "feat: add atomic Example CRUD and upsert"
```

### 작업 8: Category/Tags relationship와 related endpoint 구현

**파일:**
- 생성: `app/controllers/concerns/jsonapi_relationships.rb`
- 수정: `app/controllers/concerns/crud_actions.rb`
- 수정: `app/controllers/api/v1/examples_controller.rb`
- 수정: `config/routes.rb`
- 수정: `spec/routing/api/v1/examples_routing_spec.rb`
- 생성: `spec/requests/api/v1/example_relationships_spec.rb`
- 생성: `spec/requests/api/v1/example_relationship_concurrency_spec.rb`

- [ ] **8.1 실패 테스트 작성**

요청 spec으로 설계의 8개 relationship/related method-path 조합을 모두 고정한다. 추가로 다음을 검증한다.

routing spec은 작업 7의 6개 기본 mapping에 8개 relationship/related mapping을 더해 정확한 14개 Example method-path-action set을 검증하고, Rails form용 `new`/`edit` action route가 생성되지 않았음을 계속 확인한다.

- to-one null 교체와 잘못된 type/id의 오류
- to-many POST 추가, PATCH 전체 교체, DELETE 제거의 204
- 관련 resource가 없으면 `RELATIONSHIP_RESOURCE_NOT_FOUND`
- linkage와 related 응답의 type/id/link
- parent row가 `FOR UPDATE`로 잠김
- 같은 tag 동시 POST 두 요청 모두 204이고 join row는 하나
- relationship hook/serialization 실패 시 join 변경 rollback

relationship 동시성 example group도 `self.use_transactional_tests = false`로 선언하고 `DatabaseCleaner.clean_with(:truncation)` before/after, commit된 setup data, thread별 `ActionDispatch::Integration::Session` 및 Active Record connection, barrier를 사용한다. 두 요청이 실제로 같은 parent row lock을 경쟁했는지 확인하고, 모든 thread/connection을 종료한 뒤 truncation한다.

- [ ] **8.2 실패 확인**

실행: `COVERAGE_MINIMUM=0 bundle exec rspec spec/requests/api/v1/example_relationships_spec.rb spec/requests/api/v1/example_relationship_concurrency_spec.rb spec/routing/api/v1/examples_routing_spec.rb`

예상: relationship routes/actions가 없어 실패한다.

- [ ] **8.3 최소 구현**

최종 `*unmatched` catch-all보다 위에 명시적 member routes를 추가한다.

```ruby
resources :examples, only: [] do
  member do
    get "relationships/category", action: :category_relationship
    patch "relationships/category", action: :replace_category_relationship
    get :category, action: :related_category
    get "relationships/tags", action: :tags_relationship
    post "relationships/tags", action: :add_tags_relationship
    patch "relationships/tags", action: :replace_tags_relationship
    delete "relationships/tags", action: :remove_tags_relationship
    get :tags, action: :related_tags
  end
end
```

`JsonapiRelationships`는 controller policy에서 association, cardinality, type, serializer를 조회한다. 모든 변경은 `Example.lock.find` 뒤 실행한다. tag 추가는 `insert_all(..., unique_by: primary_key)` 또는 unique violation을 성공으로 흡수하는 동등한 방식으로 멱등 처리한다. 허용되지 않은 relationship 이름은 route 자체가 존재하지 않게 한다.

- [ ] **8.4 통과 확인**

실행: `COVERAGE_MINIMUM=0 bundle exec rspec spec/requests/api/v1/example_relationships_spec.rb spec/requests/api/v1/example_relationship_concurrency_spec.rb spec/routing/api/v1/examples_routing_spec.rb`

예상: PASS.

- [ ] **8.5 커밋**

```bash
git add app/controllers/concerns/jsonapi_relationships.rb app/controllers/concerns/crud_actions.rb app/controllers/api/v1/examples_controller.rb config/routes.rb spec/requests/api/v1/example_relationship*.rb spec/routing/api/v1/examples_routing_spec.rb
git commit -m "feat: add Example relationship endpoints"
```

### 작업 9: 공개 읽기와 외부 Auth 쓰기 경계 고정

**파일:**
- 수정: `app/controllers/api_controller.rb`
- 수정: `app/controllers/api/v1/examples_controller.rb`
- 수정: `config/initializers/auth_service.rb`
- 수정: `spec/support/auth_helper.rb`
- 수정: `spec/services/auth_service_client_spec.rb`
- 생성: `spec/config/auth_service_config_spec.rb`
- 생성: `spec/requests/api/v1/examples_auth_spec.rb`

- [ ] **9.1 실패 테스트 작성**

GET index/show/relationship/related가 쿠키 없이 성공하고, POST/PATCH/PUT/DELETE 및 모든 relationship write가 쿠키 없이 `401 AUTHENTICATION_REQUIRED`인지 검증한다. `session_web` 쿠키 성공, 외부 401, timeout/connection/5xx의 `503 AUTH_SERVICE_UNAVAILABLE`, circuit open, 비활성 사용자의 `403 FORBIDDEN`도 고정한다. Authorization header만 보낸 경우 인증되지 않아야 한다. 설정 spec은 production에서 `AUTH_SERVICE_URL` 누락/blank가 부팅 실패하고 development/test에서만 `http://localhost:3001` fallback이 허용되는지 검증한다.

- [ ] **9.2 실패 확인**

실행: `COVERAGE_MINIMUM=0 bundle exec rspec spec/requests/api/v1/examples_auth_spec.rb spec/services/auth_service_client_spec.rb spec/config/auth_service_config_spec.rb`

예상: Example write before_action과 안정적인 auth error mapping이 없어 실패한다.

- [ ] **9.3 최소 구현**

`ApiController`에 `require_authenticated_user!`와 `require_active_user!`를 두고 기존 `user_check!` 계열은 호환 wrapper로 유지하거나 참조가 사라지면 제거한다. `ExamplesController`는 `create`, `update`, `upsert`, `destroy`, `replace_category_relationship`, `add_tags_relationship`, `replace_tags_relationship`, `remove_tags_relationship`에만 `before_action :require_active_user!`를 적용한다. `set_current_user`는 쿠키가 없으면 외부 호출하지 않고, 외부 401은 anonymous로 취급하며 보호 action에서 401로 변환한다. Auth initializer는 production에서 `ENV["AUTH_SERVICE_URL"]`이 없거나 blank면 즉시 raise하고, development/test에서만 localhost fallback을 사용한다.

테스트 helper는 실제 `Cookie` header를 사용하도록 고치고 bearer token helper는 제거한다.

- [ ] **9.4 통과 확인**

실행: `COVERAGE_MINIMUM=0 bundle exec rspec spec/requests/api/v1/examples_auth_spec.rb spec/services/auth_service_client_spec.rb spec/config/auth_service_config_spec.rb`

예상: PASS.

- [ ] **9.5 커밋**

```bash
git add app/controllers/api_controller.rb app/controllers/api/v1/examples_controller.rb config/initializers/auth_service.rb spec/support/auth_helper.rb spec/services/auth_service_client_spec.rb spec/config/auth_service_config_spec.rb spec/requests/api/v1/examples_auth_spec.rb
git commit -m "feat: protect Example writes with external auth"
```

### 작업 10: Blog, Email, SendGrid, Sentry 제거

**파일:**
- 삭제: `app/controllers/api/v1/blog_posts_controller.rb`
- 삭제: `app/controllers/api/v1/blog_views_controller.rb`
- 삭제: `app/controllers/api/v1/blog_author_permissions_controller.rb`
- 삭제: `app/controllers/api/v1/blog_categories_controller.rb`
- 삭제: `app/controllers/api/v1/blog_post_categories_controller.rb`
- 삭제: `app/controllers/api/v1/email_templates_controller.rb`
- 삭제: `app/models/blog_view.rb`
- 삭제: `app/models/blog_post.rb`
- 삭제: `app/models/blog_category.rb`
- 삭제: `app/models/blog_author_permission.rb`
- 삭제: `app/models/blog_post_category.rb`
- 삭제: `app/models/email_template.rb`
- 삭제: `app/serializers/blog_category_serializer.rb`
- 삭제: `app/serializers/blog_view_serializer.rb`
- 삭제: `app/serializers/blog_author_permission_serializer.rb`
- 삭제: `app/serializers/blog_post_category_serializer.rb`
- 삭제: `app/serializers/blog_post_serializer.rb`
- 삭제: `app/serializers/email_template_serializer.rb`
- 삭제: `app/services/notification_service.rb`
- 삭제: `app/services/sendgrid_email_service.rb`
- 삭제: `config/initializers/sendgrid.rb`
- 삭제: `config/initializers/sentry.rb`
- 삭제: `spec/models/blog_post_spec.rb`
- 수정: `Gemfile`
- 수정: `Gemfile.lock`
- 수정: `.env.example`
- 수정: `config/routes.rb`
- 생성: `spec/architecture/sample_domain_spec.rb`

- [ ] **10.1 실패 테스트 작성**

architecture spec은 tracked source/config/routes/Gemfile/.env.example를 읽어 `Blog`, `blog_`, `EmailTemplate`, `SendGrid`, `SENDGRID`, `Sentry`, `SENTRY` 참조가 없음을 검증한다. `AuthServiceClient`, Sidekiq, ActiveStorage 참조는 존재함을 함께 검증한다.

- [ ] **10.2 실패 확인**

실행: `COVERAGE_MINIMUM=0 bundle exec rspec spec/architecture/sample_domain_spec.rb`

예상: 기존 파일과 gem/env 참조 때문에 실패한다.

- [ ] **10.3 최소 구현**

열거한 파일과 route를 제거하고 `sendgrid-ruby`, `sentry-rails`, `sentry-ruby`를 Gemfile/lockfile에서 제거한다. `.env.example`에서 관련 변수만 제거한다. `CrudActions`와 `ApiController`에 남은 Sentry 호출도 제거한다. unrelated initializer와 gem은 건드리지 않는다.

- [ ] **10.4 통과 확인**

실행: `COVERAGE_MINIMUM=0 bundle exec rspec spec/architecture/sample_domain_spec.rb`

예상: PASS.

- [ ] **10.5 커밋**

```bash
git add -A app/controllers/api/v1 app/models app/serializers app/services config/initializers config/routes.rb Gemfile Gemfile.lock .env.example spec/models/blog_post_spec.rb spec/architecture/sample_domain_spec.rb
git commit -m "refactor: remove legacy sample integrations"
```

### 작업 11: Health contract와 개발용 Docker Compose 추가

**파일:**
- 생성: `app/controllers/health_controller.rb`
- 수정: `config/routes.rb`
- 수정: `Dockerfile`
- 수정: `.dockerignore`
- 생성: `docker-compose.yml`
- 생성: `docker/wiremock/mappings/auth-me-success.json`
- 생성: `docker/wiremock/mappings/auth-me-unauthorized.json`
- 수정: `.env.example`
- 수정: `config/environments/development.rb`
- 생성: `spec/requests/health_spec.rb`
- 생성: `spec/docker/compose_contract_spec.rb`

- [ ] **11.1 실패 테스트 작성**

health spec은 `/health/live`가 DB를 호출하지 않고 200, `/health/ready`가 `SELECT 1` 성공 시 200인지 검증한다. ready에서 `ActiveRecord::ActiveRecordError` 또는 connection 오류가 발생하면 global 500 handler로 넘어가지 않고 503을 반환하며 SQL·exception class·message를 노출하지 않는지도 검증한다. Compose contract spec은 YAML을 파싱해 아래를 검증한다.

- 서비스가 정확히 `db`, `redis`, `auth-stub`, `migrate`, `api`, `worker`
- postgres:18과 Redis healthcheck/volume
- Rails 3개 서비스가 development target, `RAILS_ENV=development`, `DEV_DATABASE_*`, port 4000 사용
- migrate가 `db:prepare`만 실행하고 api/worker command에 migration 없음
- worker가 migration completion과 Redis healthy를 기다림
- worker command가 정확히 `bundle exec sidekiq`
- api command가 정확히 `bundle exec puma -C config/puma.rb`
- api와 worker의 `REDIS_URL`이 `redis://redis:6379/0`
- API readiness가 Redis에 의존하지 않음
- Auth URL이 `http://auth-stub:8080`
- WireMock mapping은 `session_web=dev-session`만 200, 그 외 401
- production final image에 `docker/wiremock`이 copy되지 않음
- Docker HEALTHCHECK 경로 `/health/ready`

- [ ] **11.2 실패 확인**

실행: `COVERAGE_MINIMUM=0 bundle exec rspec spec/requests/health_spec.rb spec/docker/compose_contract_spec.rb`

예상: readiness가 DB를 확인하지 않고 Compose가 없어 실패한다.

- [ ] **11.3 최소 구현**

`HealthController < ApplicationController`는 JSON:API Accept 협상이나 인증 callback 없이 `live`와 `ready`만 구현한다. live는 DB를 전혀 참조하지 않는다. ready는 `ActiveRecord::Base.connection.select_value("SELECT 1")`을 호출하고 성공 시 200을 반환하되, `ActiveRecord::ActiveRecordError`와 DB connection 오류만 action 안에서 명시적으로 rescue해 내부 detail 없는 503 readiness 응답으로 바꾼다. 다른 programming error는 rescue하지 않아 작업 5의 global 500 handler가 처리하게 한다. Dockerfile은 공통 base/bundle 단계, 모든 gem을 포함하는 `development`, dev/test를 제외한 최종 production stage로 구성한다. final command는 Puma만 실행한다.

Compose에는 명명된 DB/Redis volume, healthchecks, `depends_on` condition을 명시하고 api command를 `bundle exec puma -C config/puma.rb`, worker command를 `bundle exec sidekiq`로 고정한다. api와 worker에는 `REDIS_URL=redis://redis:6379/0`을 명시해 container localhost fallback을 막는다. 우선순위 1의 WireMock success mapping은 `session_web=dev-session` 쿠키에만 fixed active user JSON을 반환한다. 우선순위 10의 catch-all mapping은 같은 `/api/auth/me` 요청에 401을 반환한다. `.dockerignore`에는 `/docker/wiremock`을 추가해 production build context에서 제외하되 Compose는 bind mount로 사용한다.

development 설정의 ActiveStorage는 env 기본 `local`, queue adapter는 env/Compose에서 Sidekiq를 쓰도록 정합화하고 port/default_url_options/hosts를 4000으로 맞춘다.

- [ ] **11.4 통과 확인**

실행: `COVERAGE_MINIMUM=0 bundle exec rspec spec/requests/health_spec.rb spec/docker/compose_contract_spec.rb`

실행: `docker compose config --quiet`

예상: 둘 다 PASS.

- [ ] **11.5 커밋**

```bash
git add app/controllers/health_controller.rb config/routes.rb Dockerfile .dockerignore docker-compose.yml docker/wiremock .env.example config/environments/development.rb spec/requests/health_spec.rb spec/docker/compose_contract_spec.rb
git commit -m "feat: add Rails development compose stack"
```

### 작업 12: README와 CI를 실제 계약에 맞추고 전체 검증

**파일:**
- 수정: `README.md`
- 수정: `.github/workflows/ci.yml`
- 수정: `spec/swagger_helper.rb`
- 수정: `spec/architecture/sample_domain_spec.rb`

- [ ] **12.1 실패 테스트/검사 작성**

CI workflow에 별도 `container` job을 추가해 `docker compose config --quiet`와 production image build를 실행하도록 한다. README 회귀 검사는 `spec/architecture/sample_domain_spec.rb`에 다음 필수 문구를 추가한다.

- `docker compose up --build`
- `session_web=dev-session`
- Auth stub은 development 전용이며 production은 실제 `AUTH_SERVICE_URL` 필요
- JSON:API Accept/Content-Type
- Example CRUD/relationship 예시
- 초기 스키마 교체로 기존 로컬 DB reset 필요
- RSpec/SimpleCov 80%, RuboCop, Brakeman 명령

- [ ] **12.2 실패 확인**

실행: `COVERAGE_MINIMUM=0 bundle exec rspec spec/architecture/sample_domain_spec.rb`

예상: 기존 Blog/SendGrid 중심 README라 실패한다.

- [ ] **12.3 최소 구현**

README를 한국어로 다시 작성하고 로컬 Ruby 실행과 Compose 실행을 분리한다. Swagger base server/port 및 Example schema/path를 갱신한다. CI의 기존 RSpec, RuboCop, Brakeman job은 유지하고 container 검증만 추가한다.

- [ ] **12.4 전체 검증**

실행: `unset COVERAGE_MINIMUM`

예상: 아래 전체 suite가 기본 80% gate를 사용한다.

실행: `bundle exec rspec`

예상: 전체 PASS, SimpleCov line coverage 80% 이상.

실행: `bundle exec rubocop`

예상: no offenses.

실행: `bundle exec brakeman --no-pager -q`

예상: no warnings that fail CI.

실행: `docker compose config --quiet`

예상: exit 0.

실행: `docker build --target development -t template-ruby-rails:development .`

예상: development image build 성공.

실행: `docker build -t template-ruby-rails:production .`

예상: production image build 성공, development/test gems와 WireMock mapping 부재.

실행: `docker compose -p template-ruby-rails-verification down -v --remove-orphans`

예상: 이전 검증 project와 volume이 없어짐; project가 없었던 경우도 exit 0.

실행: `docker compose -p template-ruby-rails-verification up -d --build --wait`

예상: migrate exits 0, db/redis/api/worker/auth-stub healthy 또는 running.

실행: `curl -fsS http://localhost:4000/health/ready`

예상: HTTP 200.

실행: `curl -fsS -H 'Accept: application/vnd.api+json' http://localhost:4000/api/v1/examples`

예상: HTTP 200 JSON:API document.

실행: `curl -fsS -X POST -H 'Accept: application/vnd.api+json' -H 'Content-Type: application/vnd.api+json' -H 'Cookie: session_web=dev-session' --data '{"data":{"type":"examples","attributes":{"title":"Compose Example","status":"draft","score":0}}}' http://localhost:4000/api/v1/examples`

예상: HTTP 201, Location과 data.links.self 일치.

실행: `docker compose -p template-ruby-rails-verification down -v --remove-orphans`

예상: Compose 리소스가 제거된다.

실행: `docker rm -f "$RAILS_PLAN_DB_CONTAINER"`

예상: 계획 실행용 격리 PostgreSQL 컨테이너가 제거된다. 중간 검증이 실패해도 이 정리 명령은 실행한다.

- [ ] **12.5 잔존 참조와 diff 검토**

실행: `rg -n 'Blog|blog_|EmailTemplate|SendGrid|SENDGRID|Sentry|SENTRY' app config db README.md Gemfile .env.example`

예상: no matches.

실행: `git diff --check`

예상: no whitespace errors.

- [ ] **12.6 커밋**

```bash
git add README.md .github/workflows/ci.yml spec/swagger_helper.rb spec/architecture/sample_domain_spec.rb
git commit -m "docs: align Rails template verification"
```
