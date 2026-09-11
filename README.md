# Template Ruby Rails

Ruby on Rails 8 기반 JSON:API 백엔드 템플릿입니다. 공개 읽기 API, 로컬 JWT 기반
가입·로그인과 `Authorization: Bearer` 쓰기 인증, PostgreSQL, Sidekiq/Redis,
ActiveStorage를 포함합니다. 예제 도메인은 `Example`이며 category와 tags는
읽기 전용 리소스 및 Example 관계로 공개합니다.

## 기술 스택

- Ruby 3.4.8 / Rails 8.1.2
- PostgreSQL 18
- Redis 7 / Sidekiq
- jsonapi-serializer / rswag
- RSpec / SimpleCov / RuboCop / Brakeman

## Docker Compose로 실행

Docker와 Docker Compose만 있으면 개발 스택 전체를 실행할 수 있습니다.

```bash
docker compose up --build
```

다음 서비스가 함께 시작됩니다.

- `db`: PostgreSQL
- `redis`: Sidekiq broker
- `migrate`: `bin/rails db:prepare` 실행 후 종료
- `api`: `http://localhost:4000`
- `worker`: Sidekiq worker

API 준비 상태는 다음 명령으로 확인합니다.

```bash
curl -fsS http://localhost:4000/health/ready
```

종료하면서 데이터 volume까지 제거하려면 다음 명령을 사용합니다.

```bash
docker compose down -v --remove-orphans
```

## 로컬 Ruby로 실행

Ruby 3.4.8, PostgreSQL, Redis가 필요합니다.

```bash
bundle install
cp .env.example .env
bin/rails db:prepare
bin/rails server -p 4000
```

`.env`의 `DATABASE_HOST`, `DEV_DATABASE_*`, `REDIS_URL`, `JWT_SECRET_KEY`를 로컬
환경에 맞게 설정합니다. `JWT_SECRET_KEY`는 코드에 기본값이 없어 비어 있으면 부팅이
실패합니다. API 문서는 `http://localhost:4000/api-docs`에서 확인할 수 있습니다.
OpenAPI JSON은 `/api/schema`, 같은 스키마의 YAML은 `/api-docs/v1/swagger.yaml`에서
제공합니다. 요청 스펙에서 스키마를 다시 생성하려면 테스트 DB 설정 후 다음을 실행합니다.

```bash
bundle exec rake rswag:specs:swaggerize
```

`GET /health/live`와 `GET /health/ready`는 성공 시 HTTP 200과 다음 JSON:API 문서를
반환합니다. readiness는 PostgreSQL 연결을 확인하며 DB 오류는 HTTP 503의 JSON:API
`INTERNAL_SERVER_ERROR`로 반환합니다.

```json
{"data":null,"meta":{"status":"ok"},"jsonapi":{"version":"1.1"}}
```

## JSON:API 사용

리소스 요청과 응답은 JSON:API 1.1과 아래 미디어 타입을 사용합니다.
응답 시각은 UTC `+00:00`이며 마이크로초가 있으면 소수부 6자리를 유지합니다
(예: `2026-01-01T00:00:00.123456+00:00`, 정각은 `2026-01-01T00:00:00+00:00`).

```text
Accept: application/vnd.api+json
Content-Type: application/vnd.api+json
```

읽기는 공개되어 있으며 Example 쓰기에는 유효한 `Authorization: Bearer` 액세스 토큰이
필요합니다. 토큰은 아래 인증 절차로 직접 발급받습니다.

### 인증

가입 후 로그인하면 access/refresh 토큰 쌍(`authTokens`)을 받습니다. `accessToken`을
`Authorization: Bearer` 헤더에 실어 보호된 라우트(Example 쓰기, `/api/v1/users/me`)를
호출합니다.

```text
POST /api/v1/auth/register  data.type=users           -> 201 users            (Location: /api/v1/users/me)
POST /api/v1/auth/login     data.type=authCredentials -> 200 authTokens
POST /api/v1/auth/refresh   data.type=refreshTokens   -> 200 authTokens
POST /api/v1/auth/logout    data.type=refreshTokens   -> 204
```

가입합니다.

```bash
curl -i -X POST \
  -H 'Accept: application/vnd.api+json' \
  -H 'Content-Type: application/vnd.api+json' \
  --data '{"data":{"type":"users","attributes":{"email":"dev@example.com","password":"correct-horse-battery"}}}' \
  http://localhost:4000/api/v1/auth/register
```

로그인해서 토큰을 받습니다.

```bash
curl -fsS -X POST \
  -H 'Accept: application/vnd.api+json' \
  -H 'Content-Type: application/vnd.api+json' \
  --data '{"data":{"type":"authCredentials","attributes":{"email":"dev@example.com","password":"correct-horse-battery"}}}' \
  http://localhost:4000/api/v1/auth/login
```

응답의 `data.attributes.accessToken`을 이후 요청의 `Authorization` 헤더에 사용합니다.

```bash
ACCESS_TOKEN=발급받은-accessToken

curl -fsS \
  -H 'Accept: application/vnd.api+json' \
  -H "Authorization: Bearer $ACCESS_TOKEN" \
  http://localhost:4000/api/v1/users/me
```

`accessToken`이 만료되면 `data.attributes.refreshToken`으로 새 토큰 쌍을 발급받고
(`/api/v1/auth/refresh`), 더 이상 필요 없어지면 같은 `refreshToken`으로 로그아웃합니다
(`/api/v1/auth/logout`, 204, 본문 없음).

`refreshToken`은 클라이언트의 보안 저장소에 안전하게 보관해야 합니다. 서버는 토큰을
cookie에 저장하지 않고 JSON body로만 발급하며, 인증도 `Authorization` 헤더로만 받습니다.
위 `ACCESS_TOKEN` 같은 shell 변수는 예제 요청을 마친 뒤 `unset`하거나 shell을 종료합니다.

`logout`은 refresh session만 폐기합니다 — **이미 발급된 access token은 폐기되지 않고
만료될 때까지 그대로 유효합니다**(`JWT_ACCESS_EXPIRES_SECONDS`, 기본 `900`초이므로 최대
15분). 로그아웃 즉시 모든 접근을 끊어야 하는 서비스라면 access token 수명을 더 줄이거나
별도의 폐기 목록을 두어야 합니다.

로그인과 회전마다 `refresh_sessions`에 행이 쌓이고 로그아웃은 `revoked_at`만 표시합니다.
아래 백그라운드 작업 절의 `PurgeExpiredRefreshSessionsJob`을 명시적으로 enqueue하거나
스케줄을 설정해 오래된 세션을 정리합니다.

### Example CRUD

목록을 조회합니다.

```bash
curl -fsS \
  -H 'Accept: application/vnd.api+json' \
  http://localhost:4000/api/v1/examples
```

Example을 생성합니다(`$ACCESS_TOKEN`은 위 "인증" 절에서 로그인으로 받은 값).

```bash
curl -i -X POST \
  -H 'Accept: application/vnd.api+json' \
  -H 'Content-Type: application/vnd.api+json' \
  -H "Authorization: Bearer $ACCESS_TOKEN" \
  --data '{"data":{"type":"examples","attributes":{"title":"Compose Example","status":"draft","score":0}}}' \
  http://localhost:4000/api/v1/examples
```

단건 조회, 일부 수정, 전체 교체, 삭제에는 `/api/v1/examples/{id}`를 사용합니다.

POST와 PUT은 `data.attributes`의 `title`, `status`, `score`가 모두 필수입니다.
생성 시 이 값을 DB 기본값으로 채우지 않습니다. PUT은 경로와 같은 `data.id`가 필요하며,
해당 ID가 없으면 생성(201), 있으면 전체 교체(200)합니다. PATCH는 보낸 필드만 수정합니다.

```text
GET    /api/v1/examples/{id}
PATCH  /api/v1/examples/{id}
PUT    /api/v1/examples/{id}
DELETE /api/v1/examples/{id}
```

목록은 `filter`, `sort`, `include`, `page[number]`, `page[size]` query를 지원합니다.
`page[after]` 또는 `page[before]`를 사용하는 cursor 페이지네이션도 지원하며,
응답의 `links.next`/`links.prev`를 따라 이동합니다. 페이지 크기는 최대 100이고,
이동할 페이지가 없는 링크는 `null`입니다. `contains` 필터는 대소문자를 구분합니다.

```bash
curl --globoff -fsS \
  -H 'Accept: application/vnd.api+json' \
  'http://localhost:4000/api/v1/examples?filter[status]=draft&sort=-createdAt&include=category,tags'
```

### Example 관계

Category와 Tag는 다음 공개 읽기 전용 경로에서 조회할 수 있습니다.

```text
GET /api/v1/categories
GET /api/v1/categories/{id}
GET /api/v1/tags
GET /api/v1/tags/{id}
```

이 경로에는 쓰기 API가 없으며 지원하지 않는 HTTP 메서드는 `405 HTTP_ERROR`입니다.
Example의 관계를 읽거나 수정할 때는 아래 relationship/related 경로를 사용합니다.

```text
GET   /api/v1/examples/{id}/relationships/category
PATCH /api/v1/examples/{id}/relationships/category
GET   /api/v1/examples/{id}/category

GET    /api/v1/examples/{id}/relationships/tags
POST   /api/v1/examples/{id}/relationships/tags
PATCH  /api/v1/examples/{id}/relationships/tags
DELETE /api/v1/examples/{id}/relationships/tags
GET    /api/v1/examples/{id}/tags
```

Category를 교체하는 예시입니다.

```bash
curl -i -X PATCH \
  -H 'Accept: application/vnd.api+json' \
  -H 'Content-Type: application/vnd.api+json' \
  -H "Authorization: Bearer $ACCESS_TOKEN" \
  --data '{"data":{"type":"exampleCategories","id":"CATEGORY_UUID"}}' \
  http://localhost:4000/api/v1/examples/EXAMPLE_UUID/relationships/category
```

## 데이터베이스 마이그레이션과 시드

기존 DB는 새 migration을 순서대로 적용합니다. `20260911000000_align_shared_contracts.rb`는
category/tag 이름을 최대 200자로 제한하고 Example의 `status`/`score` 기본값을 제거합니다.
저장된 행은 유지하며, 200자를 넘는 이름이 있으면 잘라 저장하지 않고 migration을 실패시킵니다.
해당 값을 정리한 뒤 다시 실행합니다.

```bash
bin/rails db:migrate
bin/rails db:seed
```

시드는 다음 고정 UUID의 공통 데모 그래프를 한 트랜잭션으로 upsert합니다.

| 리소스 | UUID | 기본값 |
| --- | --- | --- |
| category | `00000000-0000-4000-8000-000000000001` | 기본 카테고리 |
| tag | `00000000-0000-4000-8000-000000000002` | 기본 태그 |
| example | `00000000-0000-4000-8000-000000000003` | JSON:API 예시, active, score 90 |

Example은 위 category와 tag에 연결됩니다. 재실행하면 시드가 관리하는 값과 기본 관계를
복구하고 추가 데이터 및 사용자가 추가한 tag 관계는 유지합니다. 변경 없는 재실행은
기존 timestamp를 유지하며, 동시 실행도 ID/관계의 고유 제약을 이용해 중복 생성을 막습니다.

## 백그라운드 작업

`bundle exec sidekiq` 또는 Compose의 `worker`가 Redis 큐를 처리합니다. worker에도
DB 설정, `REDIS_URL`, `JWT_SECRET_KEY`가 필요합니다.

```bash
bin/rails runner 'ProcessExampleJob.perform_later("00000000-0000-4000-8000-000000000003")'
bin/rails runner 'PurgeExpiredRefreshSessionsJob.perform_later'
```

`ProcessExampleJob`은 Example을 조회하고 처리 로그를 남깁니다. 잘못된 UUID나 없는
리소스는 건너뛰며 저장된 Example을 수정하지 않습니다. 이미지 variant 처리를 위한
ActiveStorage 작업도 유지합니다.

`PurgeExpiredRefreshSessionsJob`은 만료된 지 `REFRESH_SESSION_RETENTION_SECONDS`
(기본 7일)를 넘긴 세션을 오래된 순서로 기본 1,000개씩 삭제합니다. 각 배치는 별도
트랜잭션이며 잠긴 후보는 건너뛰고, 참조 행의 잠금 대기는 2,000ms로 제한합니다.
두 작업 모두 Sidekiq의 최초 실행과 재시도 3회를 합쳐 최대 4회 시도하며,
재시도 n의 대기는 `15 * 2**(n-1)`초에 `0..(10*n-1)` 범위에서 균등하게 뽑은 정수 초를 더한 값입니다. 따라서 차례로 15–24초, 30–49초, 60–89초 기다립니다. DB 오류는 재시도를 위해 그대로 전파됩니다.

정리는 한 번의 실행에서 최대 10,000배치입니다. 직접 호출의 배치 크기는 `1..9007199254740991`의 정수 값인 숫자만 허용하며 `1.0`도 허용합니다. 문자열·불리언·범위 밖 값은 DB에 접근하지 않고 종료합니다. 결과는 삭제 수 `deleted`와 실행한 배치 수 `batches`이며, 마지막 빈 배치도 셉니다.

**기본 자동 스케줄은 없습니다.** 외부 스케줄러가 위 runner 명령을 호출하게 하거나,
Sidekiq의 자체 스케줄을 사용하려면 `config/sidekiq_cron.yml`의 `{}`를 다음 내용으로
교체하고 worker를 다시 시작합니다.

```yaml
purge_expired_refresh_sessions:
  cron: "0 * * * * UTC"
  class: "PurgeExpiredRefreshSessionsJob"
  queue: "default"
```

다시 `{}`로 바꾸고 worker를 재시작하면 이 파일에서 등록한 cron 작업도 제거됩니다.
업그레이드 시 이전 기본 예약(`purge_expired_refresh_sessions`,
`PurgeExpiredRefreshSessionsJob`, `0 * * * * UTC`)도 해제합니다. 다른 동적 예약과
이미 큐에 들어간 작업은 유지합니다. 존재하지 않는 작업 클래스나 잘못된 스케줄은
worker 시작 시 오류로 드러납니다.

## 테스트와 정적 검사

전체 RSpec 실행은 SimpleCov 80% line coverage를 강제합니다.

```bash
bundle exec rspec
bundle exec rubocop
bundle exec brakeman --no-pager -q
```

특정 spec을 개발 중 실행할 때만 `COVERAGE_MINIMUM=0`으로 전체 coverage gate를 비활성화할
수 있습니다. CI와 최종 검증에서는 기본 80% gate를 사용합니다.

Compose 및 production image 계약은 다음 명령으로 확인합니다.

```bash
docker compose config --quiet
docker build --target development -t template-ruby-rails:development .
docker build -t template-ruby-rails:production .
```

## 주요 경로

```text
app/controllers/api/v1/examples_controller.rb  Example API 정책
app/controllers/api/v1/auth_controller.rb       가입·로그인·refresh·로그아웃
app/controllers/concerns/crud_actions.rb        공통 CRUD 및 관계 동작
app/controllers/concerns/jsonapi_authentication.rb  Bearer 액세스 토큰 가드
app/lib/auth/                                    비밀번호 해시, JWT, refresh 세션 원시 함수
app/jobs/                                        Sidekiq 작업
config/routes.rb                                 API와 health 경로
docker-compose.yml                               개발 스택
spec/                                            계약 및 회귀 테스트
```
