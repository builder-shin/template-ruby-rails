# Rails Example API 대칭화 설계

## 목표

`template-ruby-rails`의 Blog 및 이메일 예제 도메인을 제거하고, `template-python-fastapi`와 같은 `Example` 공개 계약을 제공한다. Rails 생태계 고유 기능인 외부 인증과 Sidekiq는 유지하되, JSON:API 리소스 구조·HTTP 동작·조회 정책·오류 계약은 FastAPI 템플릿과 맞춘다.

## 성공 기준

- 공개 도메인 API는 `/api/v1/examples` 하나만 존재한다.
- `Example`은 `title`, `description`, `status`, `score`, `createdAt`, `updatedAt`을 공개한다.
- `category`와 `tags`는 Example 관계로만 공개하고 독립 CRUD 라우트를 만들지 않는다.
- FastAPI 템플릿과 같은 CRUD, 원자적 `PUT` upsert, relationship/related 엔드포인트를 제공한다.
- JSON:API 미디어 타입, 조회 허용 목록, 한·영 오류 계약을 요청 테스트로 고정한다.
- 쓰기 요청은 기존 외부 Auth 세션을 요구하고 읽기 요청은 공개한다.
- Blog, EmailTemplate, SendGrid, Sentry 코드와 설정이 저장소에서 사라진다.
- Docker Compose로 PostgreSQL, Redis, migration, API, Sidekiq worker를 함께 실행할 수 있다.
- 개발용 Compose에는 외부 Auth 계약을 재현하는 격리된 Auth stub을 포함해 읽기와 쓰기 API를 모두 검증할 수 있다.
- RSpec 전체 실행에서 SimpleCov 80% 이상을 강제한다.

## 비목표

- Rails 인증을 자체 JWT로 교체하지 않는다.
- ActiveStorage, Sidekiq, rack-attack, lograge, rswag를 제거하지 않는다.
- FastAPI 내부 구현 방식을 Ruby로 직역하지 않는다.
- category와 tag의 독립 관리 API를 추가하지 않는다.
- 운영 환경의 외부 Auth 서비스를 Rails 저장소 안에 구현하지 않는다.

## 공개 리소스 계약

### 저장 모델

- `Example`
  - UUID 기본 키
  - `title`: 1~200자 필수 문자열
  - `description`: 선택 문자열
  - `status`: `draft`, `active`, `archived`
  - `score`: 0~100 정수
  - `category_id`: 선택 UUID 외래 키, 삭제 시 `NULL`
  - timestamps
- `ExampleCategory`
  - UUID 기본 키
  - 고유한 `name`
  - JSON:API type `exampleCategories`
  - timestamps
- `ExampleTag`
  - UUID 기본 키
  - 고유한 `name`
  - JSON:API type `exampleTags`
  - timestamps
- `ExampleTagging`
  - `example_id`, `tag_id` 복합 기본 키
  - 양쪽 삭제 시 cascade

### 직렬화

`ExampleSerializer`만 최상위 공개 리소스를 소유한다. 공개 type은 `examples`이며 attributes는 `title`, `description`, `status`, `score`, `createdAt`, `updatedAt`이다. relationships는 `category`, `tags`를 이 순서와 이름으로 공개한다. Category와 Tag serializer는 각각 `exampleCategories`, `exampleTags` type과 `name` attribute를 포함 리소스 및 related 응답에만 사용한다.

Example resource는 `/api/v1/examples/{정규화된 UUID}` self link를 갖는다. 관계 객체는 `/relationships/{name}` self link와 `/{name}` related link를 갖는다. Category와 Tag는 독립 public 경로가 없으므로 자체 self link를 만들지 않는다.

### 엔드포인트

| 메서드 | 경로 | 인증 | 결과 |
| --- | --- | --- | --- |
| `GET` | `/api/v1/examples` | 공개 | 목록 |
| `POST` | `/api/v1/examples` | 필요 | 생성, `201` |
| `GET` | `/api/v1/examples/{id}` | 공개 | 단건 조회 |
| `PATCH` | `/api/v1/examples/{id}` | 필요 | 일부 수정, `200` |
| `PUT` | `/api/v1/examples/{id}` | 필요 | 생성 `201` 또는 전체 교체 `200` |
| `DELETE` | `/api/v1/examples/{id}` | 필요 | 삭제, `204` |
| `GET` | `/api/v1/examples/{id}/relationships/category` | 공개 | category linkage |
| `PATCH` | `/api/v1/examples/{id}/relationships/category` | 필요 | category 교체 |
| `GET` | `/api/v1/examples/{id}/category` | 공개 | related category |
| `GET` | `/api/v1/examples/{id}/relationships/tags` | 공개 | tags linkage |
| `POST` | `/api/v1/examples/{id}/relationships/tags` | 필요 | tags 추가 |
| `PATCH` | `/api/v1/examples/{id}/relationships/tags` | 필요 | tags 전체 교체 |
| `DELETE` | `/api/v1/examples/{id}/relationships/tags` | 필요 | tags 제거 |
| `GET` | `/api/v1/examples/{id}/tags` | 공개 | related tags |

## 공통 CRUD 확장

`CrudActions`에 다음 재사용 기능을 추가한다.

- `PUT` create/replace upsert
- serializer가 선언한 관계의 linkage와 related 응답
- to-one 교체와 to-many 추가·교체·삭제
- 쓰기 transaction 안에서 모델 저장, 관계 반영, 직렬화를 완료한 뒤 commit
- 같은 UUID로 동시에 생성되는 `PUT`을 PostgreSQL advisory transaction lock으로 직렬화
- `PUT`에서 생략한 `category`는 `null`, 생략한 `tags`는 빈 목록으로 전체 교체한다.
- `PATCH`는 attributes 없이 relationships만 포함한 문서를 허용한다.
- 관계 변경은 부모 Example row를 `FOR UPDATE`로 잠근 뒤 수행한다.
- 같은 tag를 동시에 추가해도 join row는 하나만 남고 두 요청 모두 성공하는 멱등성을 보장한다.
- 직렬화 또는 after hook이 실패하면 모델과 관계 변경을 모두 rollback한다.
- 생성 응답 `Location`, 삭제 및 관계 변경 `204`
- `Location`은 응답 resource의 canonical self link와 같고 UUID는 소문자 표준 문자열로 정규화한다.
- 읽기와 쓰기 before action을 나눌 수 있는 인증 조립점

Example controller는 모델, serializer, 허용 필터·정렬·include, 관계, 인증 정책만 선언하는 얇은 구조를 유지한다.

## JSON:API 및 조회 계약

- 모든 리소스 요청의 `Accept`를 검사하고 호환되지 않으면 `406`을 반환한다.
- 본문이 있는 요청은 `Content-Type: application/vnd.api+json`을 요구하며 위반 시 `415`를 반환한다.
- type 또는 URL id가 문서와 일치하지 않으면 안정적인 JSON:API 오류를 반환한다.
- 필터와 연산자는 다음 조합만 허용한다.
  - `title`: `exact`, `contains`
  - `status`: `exact`, `in`
  - `score`: `exact`, `gt`, `gte`, `lt`, `lte`, `in`
  - `category.id`: `exact`, `in`, `isNull`
  - `createdAt`: `exact`, `gt`, `gte`, `lt`, `lte`
- 필터 문법은 `filter[field]=value`를 exact로, `filter[field][operator]=value`를 명시 연산자로 해석한다. `in` 값은 쉼표로 구분하고 `isNull`은 `true` 또는 `false`만 허용한다.
- 정렬은 `title`, `status`, `score`, `createdAt`, `updatedAt`만 허용한다.
- 기본 정렬은 `-createdAt,id`이며 사용자 정렬에도 마지막 tie-breaker로 `id`를 한 번만 추가한다.
- include는 `category`, `tags`만 허용한다.
- 페이지는 `page[number]`, `page[size]`이며 기본 크기는 20, 최대 크기는 100이다.
- 목록 응답은 `meta.totalCount`와 `self`, `first`, `prev`, `next`, `last` 페이지 link를 포함한다.
- 빈 `include=`는 빈 `included` 배열을 반환하고 중복 include는 응답에서 한 번만 처리한다.
- 알 수 없는 필터·정렬·include·페이지 키, 허용하지 않은 연산자, 같은 단일 query parameter의 중복은 묵살하지 않고 `400` 오류로 반환한다.

## 오류와 언어

오류 객체는 안정적인 `code`, HTTP `status`, `title`, `detail`, 가능한 경우 `source.pointer` 또는 `source.parameter`를 포함한다. `Accept-Language`에서 `ko`와 `en`을 선택하고 기본 언어는 한국어로 한다. 내부 예외, SQL, 인증 서비스 응답 본문은 노출하지 않는다.

공통 code는 FastAPI와 같은 `NOT_ACCEPTABLE`, `UNSUPPORTED_MEDIA_TYPE`, `INVALID_JSONAPI_DOCUMENT`, `INVALID_QUERY_PARAMETER`, `INVALID_FILTER`, `INVALID_SORT`, `INVALID_INCLUDE`, `INVALID_PAGE`, `RESOURCE_NOT_FOUND`, `RELATIONSHIP_RESOURCE_NOT_FOUND`, `TYPE_MISMATCH`, `ID_MISMATCH`, `CLIENT_GENERATED_ID_UNSUPPORTED`, `RESOURCE_CONFLICT`, `VALIDATION_ERROR`, `INTERNAL_SERVER_ERROR`, `HTTP_ERROR`를 사용한다. Rails 인증 경계에는 `AUTHENTICATION_REQUIRED`, `FORBIDDEN`, `AUTH_SERVICE_UNAVAILABLE`를 추가한다.

## 도메인 및 외부 연동 정리

다음 항목을 제거한다.

- 모든 `Blog*` 모델·컨트롤러·serializer·factory·spec·seed·route
- `EmailTemplate` 모델·컨트롤러·serializer·route
- `NotificationService`, `SendgridEmailService`, SendGrid initializer와 환경 변수
- `sendgrid-ruby`, `sentry-rails`, `sentry-ruby` gem
- Sentry initializer, 사용자 context 설정, 예외 capture

템플릿 저장소이므로 기존 Blog/Email 마이그레이션을 유지하지 않고 초기 도메인 마이그레이션을 Example 스키마로 교체한다. 기존 로컬 데이터베이스에는 reset이 필요하다는 점을 README에 명시한다.

## Docker Compose와 설정 정합성

개발용 Compose 서비스는 `db`, `redis`, `auth-stub`, `migrate`, `api`, `worker`로 구성한다.

- `db`: PostgreSQL 18, healthcheck와 영속 volume
- `redis`: Sidekiq broker, healthcheck와 영속 volume
- `auth-stub`: 고정된 `session_web=dev-session` 쿠키에만 테스트 사용자를 반환하는 WireMock 서비스
- `migrate`: DB 준비 후 `bin/rails db:prepare`, 성공 후 종료
- `api`: migration 성공 후 Puma 실행, 호스트 포트 4000
- `worker`: migration과 Redis 준비 후 Sidekiq 실행

Dockerfile에 모든 gem을 설치하는 `development` target과 development/test를 제외하는 최종 production image를 분리한다. Compose의 `migrate`, `api`, `worker`는 development target과 `RAILS_ENV=development`, `DEV_DATABASE_*`를 사용한다. 따라서 production의 SSL 강제와 `PRD_DATABASE_*` 설정이 로컬 Compose에 적용되지 않는다. production image는 외부 배포용으로 유지하며 Auth stub을 포함하지 않는다.

Compose의 Rails 서비스는 `AUTH_SERVICE_URL=http://auth-stub:8080`을 사용한다. production은 사용자가 지정한 실제 `AUTH_SERVICE_URL`을 요구한다. Auth stub mapping은 저장소에 추적하되 development 전용임을 README에 경고하고 production compose나 image에는 복사하지 않는다.

포트는 README, `.env.example`, Puma, Dockerfile, Compose에서 4000으로 통일한다. `/health/live`는 프로세스 생존만, `/health/ready`는 PostgreSQL `SELECT 1` 성공을 확인한다. Redis 장애는 읽기·인증 API의 readiness를 막지 않는다. Dockerfile healthcheck는 `/health/ready`를 사용한다. 컨테이너 시작 명령에서 migration을 제거해 Compose의 단일 migration 서비스가 소유하도록 한다. 개발 기본 자격 증명은 개발 전용임을 문서화한다.

## 테스트 전략

SimpleCov는 Rails 로딩 전에 시작하고 전체 `app` 코드에 최소 80%를 강제한다. 제외 경로는 Rails 생성 wiring인 `app/channels/application_cable/*`, `app/helpers/application_helper.rb`, `app/mailers/application_mailer.rb`로 한정한다.

- 모델: enum, 점수 범위, 필수값, UUID, 관계, cascade
- serializer: attributes, linkage, included, canonical links
- 요청: CRUD 상태·본문·헤더, 인증 경계, 필터·정렬·페이지, include
- upsert: create/replace, Location, 관계 reset, 동시 같은 UUID, rollback
- 관계: to-one과 to-many 전체 동작, 중복 요청의 멱등성, 잘못된 type/id
- 협상: 406·415와 JSON:API Content-Type
- 오류: 한국어·영어, pointer/parameter, 404·409·422·500 비노출
- 외부 Auth: 성공·캐시·401·timeout·회로 차단기
- Auth stub: 허용 쿠키 성공, 다른 쿠키 401, production 비포함
- Docker/설정: Compose config, 포트와 healthcheck 정합성

CI는 RSpec 커버리지 게이트, RuboCop, Brakeman을 유지하고 Docker Compose config 및 이미지 build를 추가한다.

## 문서

README를 Example 중심으로 다시 작성한다. Docker Compose 실행, 로컬 실행, 개발 전용 Auth stub과 `dev-session` 쿠키, 운영 외부 Auth 요구사항, JSON:API 헤더, Example 요청, 관계 요청, 테스트 명령, 초기 스키마 변경에 따른 DB reset 주의를 한국어로 설명한다.
