# Template Ruby Rails

Ruby on Rails 8 기반 JSON:API 백엔드 템플릿입니다. 공개 읽기 API, 로컬 JWT 기반
가입·로그인과 `Authorization: Bearer` 쓰기 인증, PostgreSQL, Sidekiq/Redis,
ActiveStorage를 포함합니다. 예제 도메인은 단일 `Example` 리소스이며 category와 tags는
관계로만 공개합니다.

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
- `auth-stub`: 개발 인증 응답을 제공하는 WireMock
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

### 개발용 Auth stub

Auth stub은 development 전용입니다. `session_web=dev-session` 쿠키에만 고정된 개발
사용자를 반환합니다. production에서는 이 stub을 사용하지 않으며 실제 외부 인증 서비스의
`AUTH_SERVICE_URL`을 반드시 설정해야 합니다.

## 로컬 Ruby로 실행

Ruby 3.4.8, PostgreSQL, Redis가 필요합니다.

```bash
bundle install
cp .env.example .env
bin/rails db:prepare
bin/rails server -p 4000
```

`.env`의 `DATABASE_HOST`, `DEV_DATABASE_*`, `REDIS_URL`, `AUTH_SERVICE_URL`을 로컬
환경에 맞게 설정합니다. API 문서는 `http://localhost:4000/api-docs`에서 확인할 수 있습니다.

## JSON:API 사용

리소스 요청과 응답은 JSON:API 미디어 타입을 사용합니다.

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

```text
GET    /api/v1/examples/{id}
PATCH  /api/v1/examples/{id}
PUT    /api/v1/examples/{id}
DELETE /api/v1/examples/{id}
```

목록은 `filter`, `sort`, `include`, `page[number]`, `page[size]` query를 지원합니다.

```bash
curl --globoff -fsS \
  -H 'Accept: application/vnd.api+json' \
  'http://localhost:4000/api/v1/examples?filter[status]=draft&sort=-createdAt&include=category,tags'
```

### Example 관계

Category와 Tag에는 독립 CRUD 경로가 없습니다. Example의 relationship/related 경로를
사용합니다.

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

## 데이터베이스 초기화 주의

초기 스키마가 Example 도메인으로 교체되었으므로 이전 버전에서 만든 로컬 DB는 migration만으로
전환되지 않습니다. 보존할 데이터가 없는 개발 환경에서 다음 명령으로 reset해야 합니다.

```bash
bin/rails db:reset
```

이 명령은 DB 데이터를 삭제하므로 production 또는 보존이 필요한 DB에는 사용하지 마세요.

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
app/services/auth_service_client.rb             레거시 외부 Auth 연동(단계적 제거 예정)
app/jobs/                                        Sidekiq 작업
config/routes.rb                                 API와 health 경로
docker-compose.yml                               개발 스택
spec/                                            계약 및 회귀 테스트
```
