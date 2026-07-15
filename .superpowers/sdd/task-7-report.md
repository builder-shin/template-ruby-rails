# 작업 7 구현 보고서: Example CRUD와 원자적 PUT upsert

## 작업 범위

- 브랜치: `codex/align-fastapi-example-impl`
- 기준 커밋: `8d1b6db`
- 구현 대상:
  - `app/controllers/api/v1/examples_controller.rb`
  - `app/controllers/concerns/crud_actions.rb`
  - `config/routes.rb`
  - `spec/requests/api/v1/examples_crud_spec.rb`
  - `spec/requests/api/v1/examples_upsert_spec.rb`
  - `spec/routing/api/v1/examples_routing_spec.rb`
- 비대상:
  - Task 8의 relationship/related 전용 route와 action
  - Task 9의 Example write 인증 callback
  - `.superpowers/sdd/progress.md`
  - 기존 query parser 정책 변경

Task 7은 현재 `ApiController#set_current_user` 동작을 그대로 상속한다. 읽기/쓰기 인증 분리는 Task 9 소유이므로 이 작업에서 인증 callback을 추가하거나 기존 외부 Auth 경계를 완화하지 않았다.

## 사전 확인과 기준선

다음 문서와 계약을 구현 전에 전체 확인했다.

- `.superpowers/sdd/task-7-brief.md`
- `.superpowers/sdd/global-constraints.md`
- `docs/superpowers/specs/2026-07-15-example-api-parity-design.md`
- `docs/superpowers/plans/2026-07-15-rails-example-api-parity.md`의 작업 7
- FastAPI 템플릿의 CRUD/upsert transaction 및 오류 계약

`.superpowers/sdd/env.sh`를 source한 격리 PostgreSQL 환경에서 DB 연결을 확인했다. 변경 전 관련 기준선은 다음과 같다.

```bash
COVERAGE_MINIMUM=0 bundle exec rspec \
  spec/requests/api/v1/examples_query_spec.rb \
  spec/requests/api/v1/jsonapi_errors_spec.rb \
  spec/requests/api/v1/jsonapi_negotiation_spec.rb \
  spec/serializers/example_serializer_spec.rb
```

```text
48 examples, 0 failures
```

## TDD 증거

### 최초 RED

production controller와 route를 만들기 전에 CRUD, upsert, routing spec을 먼저 작성했다.

```bash
COVERAGE_MINIMUM=0 bundle exec rspec \
  spec/requests/api/v1/examples_crud_spec.rb \
  spec/requests/api/v1/examples_upsert_spec.rb \
  spec/routing/api/v1/examples_routing_spec.rb
```

```text
22 examples, 21 failures
```

실패 원인은 `/api/v1/examples`가 최종 catch-all로 들어가 모두 `404`가 되고 `Api::V1::ExamplesController` 상수가 존재하지 않는 것이었다. missing-resource 예제 한 건만 기존 catch-all의 `RESOURCE_NOT_FOUND`와 우연히 같은 결과여서 통과했다. 따라서 신규 route/action 부재를 정확히 검출하는 RED였다.

### 문서 검증 순서와 관계 허용 목록 RED

최초 GREEN 뒤 다음 두 경계를 별도 테스트로 먼저 고정했다.

- 존재하지 않는 URL에 잘못된 type을 보낸 PATCH도 row 조회보다 먼저 `TYPE_MISMATCH`를 반환한다.
- `category`, `tags` 외 관계 이름은 `INVALID_JSONAPI_DOCUMENT`로 거부한다.

production 수정 전 결과:

```text
2 examples, 2 failures
```

첫 요청은 선행 `_set_model` 때문에 `404`였고, 둘째 요청은 허용하지 않은 관계가 deserializer에서 조용히 제거돼 `200`이었다. Example update에서만 선행 `_set_model` callback을 건너뛰고 action 내부의 문서 검증 후 transaction에서 조회하도록 수정했으며, 기존 Blog ownership callback 순서는 유지했다.

## 구현 내용

### 정확한 공개 route

최종 `/api/*unmatched`보다 앞에 다음 6개 method-path-action만 추가했다.

- `GET /api/v1/examples` → `index`
- `POST /api/v1/examples` → `create`
- `GET /api/v1/examples/:id` → `show`
- `PATCH /api/v1/examples/:id` → `update`
- `PUT /api/v1/examples/:id` → `upsert`
- `DELETE /api/v1/examples/:id` → `destroy`

`new`와 `edit` route는 생성하지 않았다. `/examples/new`는 동적 `show`의 `id="new"`로 인식되고 `/examples/:id/edit`는 최종 catch-all로 들어가는 것을 route table과 route recognition으로 검증했다.

### 얇은 ExamplesController 정책

- serializer: `ExampleSerializer`
- JSON:API type: `examples`
- write attributes: `title`, `description`, `status`, `score`
- write relationships: `category`, `tags`
- Task 6 query contract: 승인된 filters/sorts/includes를 그대로 선언
- UUID: canonical 8-4-4-4-12 hexadecimal 입력만 받고 내부 조회·응답은 lowercase로 정규화

Category와 Tag의 독립 CRUD route 또는 canonical self link는 추가하지 않았다.

### JSON:API write 검증

DB transaction 전에 다음을 검증한다.

- `data`가 resource object인지 확인
- primary type 불일치: `409 TYPE_MISMATCH`, `/data/type`
- PATCH/PUT URL-body id 불일치 또는 누락: `409 ID_MISMATCH`, `/data/id`
- POST client id: `403 CLIENT_GENERATED_ID_UNSUPPORTED`, `/data/id`
- `attributes`/`relationships` container shape
- controller 허용 목록 밖의 relationship 이름
- attributes와 relationships가 모두 없는 PATCH: `422 VALIDATION_ERROR`

`ActiveRecord::RecordNotUnique`는 기존 공통 error concern을 통해 `409 RESOURCE_CONFLICT`로 변환한다.

### transaction과 응답 직렬화

POST, PATCH, PUT은 다음을 한 transaction에서 처리한다.

1. model build 또는 조회
2. attributes와 허용 relationship assignment
3. 기존 lifecycle hook
4. `save!`
5. after-save hook
6. `ExampleSerializer#serializable_hash`

commit 뒤에는 transaction 안에서 이미 만든 payload만 응답한다. serializer 또는 hook이 실패하면 attribute, category, tag join 변경이 함께 rollback된다. POST는 `201`, PATCH는 `200`, DELETE는 빈 `204`를 반환한다. 생성 `Location`은 직렬화된 `data.links.self`를 그대로 사용한다.

### 원자적 PUT upsert

- URL UUID를 lowercase canonical 값으로 정규화한다.
- transaction 안에서 `pg_advisory_xact_lock(hashtextextended(normalized_uuid, 0))`을 얻는다.
- lock 뒤에 row를 다시 조회해 없으면 요청 UUID로 build하고 있으면 같은 row를 전체 교체한다.
- 공개 column은 model default에서 시작해 요청 값을 적용한다. 따라서 생략한 `description`은 `nil`, `status`는 `draft`, `score`는 `0`이 된다.
- 생략한 `category`는 `nil`, `tags`는 빈 목록으로 초기화한다.
- 없는 row는 `201 + Location`, 기존 row는 `200`이다.
- 대문자 UUID 입력도 response id, self, Location은 lowercase이다.

동시성 spec은 `self.use_transactional_tests = false`와 `DatabaseCleaner.clean_with(:truncation)` before/after를 사용한다. 미리 commit된 category/tag를 만들고, thread마다 별도 `ActionDispatch::Integration::Session`과 connection pool lease를 사용한다. `Concurrent::CyclicBarrier` 이후 두 PUT을 실제로 경쟁시켜 결과 status가 정확히 `200`, `201` 하나씩이고 최종 Example row가 하나인지 확인한다. 모든 thread는 `with_connection` 종료로 connection을 반환하고 truncation으로 관계 row까지 정리한다.

## 최종 검증

Task 7 집중 스펙:

```text
24 examples, 0 failures
```

기존 query/errors/negotiation/serializer 회귀:

```text
48 examples, 0 failures
```

동시 PUT을 포함한 upsert spec 3회 연속 실행:

```text
7 examples, 0 failures
7 examples, 0 failures
7 examples, 0 failures
```

변경 파일 RuboCop:

```text
6 files inspected, no offenses detected
```

추가 확인:

- `ruby -c app/controllers/concerns/crud_actions.rb`: `Syntax OK`
- `ruby -c app/controllers/api/v1/examples_controller.rb`: `Syntax OK`
- `git diff --check`: 통과
- `.superpowers/sdd/progress.md`: 무변경
- 기존 Blog route/controller 및 외부 Auth 코드: 무변경

RuboCop 실행 중 Ruby 4.0에서 `benchmark`가 default gem에서 제외될 예정이라는 기존 도구 경고가 출력됐으나 변경 파일 offense는 없다.

## 후속 작업 경계

- relationship linkage/related 전용 8개 route, strict relationship type/id 검증, parent row lock, tag add 멱등성은 Task 8에서 구현한다.
- 공개 GET과 보호된 write의 외부 Auth callback 분리는 Task 9에서 구현한다.
- 기존 Blog/Email route 및 코드는 Task 10 전까지 유지한다.
