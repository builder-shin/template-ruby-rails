# Rails 계약 통일 설계

- 작성일: 2026-09-04
- 대상 저장소: `template-ruby-rails`
- 정본 구현: `template-python-fastapi`
- 관련 스펙: `template-typescript-nextjs/docs/superpowers/specs/2026-09-04-nextjs-jsonapi-template-design.md` (6장이 단계 4의 계약을 소유한다)

## 1. 목표

이 저장소의 공개 계약을 정본(FastAPI)과 **같게** 만든다. 완료 조건은 하나다 — 같은 요청에 같은 문서가 나온다.

포팅 대상은 코드가 아니라 계약이다. Rails 관용구는 유지하되, wire를 건너는 것은 전부 정본을 따른다.

세 백엔드가 같은 계약을 내면 프론트엔드는 `BACKEND_URL`만 바꿔 세 곳을 오간다. 어댑터 계층이 필요 없어지는 것이 이 작업의 목적이다.

### 1.1 실측된 차이

| 항목 | 정본 (FastAPI) | 현재 Rails |
| --- | --- | --- |
| 인증 | 자체 JWT + refresh 회전 | 외부 Auth 서비스 `session_web` 쿠키 |
| auth 라우트 | `/api/v1/auth/*` 4개 + `/users/me` | 없음 |
| 페이지네이션 | offset(probe) + keyset cursor | offset 전용, 항상 COUNT |
| `links.last` | `page[totals]=true`일 때만 | 항상 발행 |
| `meta.totalCount` | `page[totals]=true`일 때만 | 없음 |
| 오류 카탈로그 | 24개 | 20개 — 인증 6개 없음, 불필요한 2개 있음 |
| 참조 자원 라우트 | 없음 → 추가 예정 | 없음 → 추가 예정 |

리소스 스키마(`title` · `description` · `status` · `score`)와 status enum(`draft` / `active` / `archived`)은 **이미 일치한다.** 이 작업에서 건드리지 않는다.

### 1.2 비목표 (YAGNI)

- workspace 멀티테넌시의 대체물 (제거하고 끝낸다)
- Devise 등 인증 프레임워크 도입
- 토큰을 다른 백엔드와 상호 교환 가능하게 만드는 것 (각 백엔드는 자기 DB와 자기 비밀키를 갖는다)
- `fields[...]` 희소 필드셋
- 참조 자원(`categories` · `tags`)의 쓰기 라우트

### 1.3 유지하는 것

`rack-cors`와 `CORS_ALLOWED_ORIGINS`를 유지한다. CORS는 JSON:API 계약이 아니라 배포 설정이고, 제거하면 Rails를 브라우저에서 직접 부르던 사용처가 깨진다. 세 백엔드의 계약 통일과 무관하다.

## 2. 발견 — 쿼리 엔진이 Example을 알고 있다

`JsonapiQuery`는 모든 자원이 공유하는 concern인데 Example 전용 지식을 갖고 있다.

```ruby
MAX_SCORE_INTEGER = (2**31) - 1                       # Example의 score
FILTER_FIELDS = { "title" => ..., "status" => ..., "score" => ..., ... }.freeze
SORT_FIELDS   = { "title" => :title, ..., "id" => :id }.freeze

def apply_sort(scope)
  terms = @sort_terms || [ SortTerm.new("createdAt", true) ]   # 기본 정렬 하드코딩
```

컨트롤러의 `query_contract`는 **이름과 연산자만** 선언하고, 컬럼 매핑과 타입은 공유 concern이 갖는다. 정본에서는 `QueryPolicy`가 자원별로 그 전부를 갖고 엔진은 자원을 모른다.

**결과: 단계 4가 이 상태로는 불가능하다.** `name` 필터를 넣으려면 공유 상수를 모든 자원의 합집합으로 만들어야 하고, 기본 정렬이 `createdAt DESC`로 박혀 있어 `categories`의 `name ASC`도 낼 수 없다.

따라서 단계 1이 나머지 전부보다 앞선다.

## 3. 단계와 순서

```text
1. 쿼리 엔진 탈-Example화     공개 계약 변경 없음. 기존 spec이 안전망
2. 페이지네이션 계약 통일     offset 수정 + cursor 신설
3. 인증 이식                  자체 JWT. 외부 auth 제거
4. categories · tags 라우트   단계 1에 의존
```

`2`와 `3`은 건드리는 파일이 겹치지 않아(`app/lib/jsonapi/` vs `app/auth/`) 서로 독립이다. `4`는 `1` 이후 언제든 가능하다.

## 4. 단계 1 — 쿼리 엔진 탈-Example화

### 4.1 `query_contract`의 새 모양

정본 `QueryPolicy`와 같은 것을 갖는다 — 이름·연산자에 더해 컬럼·타입·기본 정렬·tie breaker.

```ruby
def query_contract
  {
    filters: {
      "title"       => { attribute: :title,       type: :string,   operators: %w[exact contains] },
      "status"      => { attribute: :status,      type: :enum,     operators: %w[exact in] },
      "score"       => { attribute: :score,       type: :integer,  operators: %w[exact gt gte lt lte in] },
      "category.id" => { attribute: :category_id, type: :uuid,     operators: %w[exact in isNull] },
      "createdAt"   => { attribute: :created_at,  type: :datetime, operators: %w[exact gt gte lt lte] }
    },
    sorts: {
      "title"     => { attribute: :title,      nullable: false },
      "status"    => { attribute: :status,     nullable: false },
      "score"     => { attribute: :score,      nullable: false },
      "createdAt" => { attribute: :created_at, nullable: false },
      "updatedAt" => { attribute: :updated_at, nullable: false }
    },
    includes:          %w[category tags],
    default_sort:      [ { field: "createdAt", direction: :desc } ],
    tie_breaker:       { field: "id", direction: :asc },
    default_page_size: 20
  }
end
```

### 4.2 공유 concern에서 사라지는 것

| 지금 | 어디로 |
| --- | --- |
| `FILTER_FIELDS` · `SORT_FIELDS` | `query_contract`로 이동 |
| `MAX_SCORE_INTEGER` | `type: :integer`가 int4 범위를 함의한다. bigint가 필요한 자원은 `type: :bigint`를 선언한다 |
| `parse_status` | `parse_enum`으로 일반화. 이미 `@model.defined_enums`를 읽고 있어 이름만 Example을 가리키고 있었다 |
| `apply_sort`의 하드코딩 기본 정렬 | `default_sort` · `tie_breaker` 선언 |

`nullable`을 지금 넣는 이유는 단계 2다 — keyset cursor가 nullable 정렬을 거부해야 하고, 그 판단 근거가 선언에 있어야 한다.

### 4.3 계약 불변

**공개 응답이 한 바이트도 달라지지 않는다.** 기존 request spec 전부가 그대로 안전망이다. 이 단계에서 응답이 바뀌면 그것은 버그다.

## 5. 단계 2 — 페이지네이션 계약 통일

### 5.1 offset 수정 — COUNT를 기본에서 뺀다

```text
현재  항상 COUNT → links.last를 항상 발행
목표  요청 크기 +1행을 읽어(probe) next 유무를 판정하고 그 한 행은 응답에서 버린다
      COUNT는 page[totals]=true에서만 실행한다
      meta.totalCount와 non-null links.last도 그때만 나온다
```

COUNT는 큰 테이블에서 목록 조회보다 비싸질 수 있다. 필요하다고 말한 요청에만 실행한다.

`kaminari`를 Gemfile에서 제거한다. 조사 결과 이 gem은 **어디에서도 쓰이지 않는다** — 현재 offset 페이지네이션은 `scope.offset(...).limit(...)`으로 손수 구현되어 있고, `Kaminari` 상수나 `.page` / `.per` 호출이 저장소에 하나도 없다. 쓰이지 않는 의존성이므로 이 변경과 함께 정리한다.

### 5.2 cursor 신설 — keyset

```text
page[after]=<opaque>    빈 문자열은 컬렉션의 시작을 가리킨다
page[before]=<opaque>   빈 문자열은 컬렉션의 끝을 가리킨다
page[number]와 함께 오면 INVALID_PAGE
```

커서는 유효 정렬의 컬럼 값들을 인코딩한 opaque 문자열이다. 클라이언트는 커서를 만들지 않고 `links`를 따라간다.

**정렬 컬럼이 NULL을 허용하면 커서 모드를 거부한다.** NULL이 섞이면 keyset 페이지가 행을 조용히 건너뛴다. Example의 정렬 컬럼은 전부 `NOT NULL`이라 실제로는 걸리지 않지만, 규칙이 코드에 있어야 나중에 nullable 정렬을 여는 사람이 막힌다.

커서 코덱이 왕복시킬 수 없는 타입의 컬럼도 거부한다 — 이유는 다르다. nullable은 행을 건너뛰는 문제이고, 이쪽은 `next` 링크를 아예 발행할 수 없는 문제다. 커서를 만들 수 없는 정렬을 받아들이면 첫 페이지 다음으로 넘어갈 방법이 없는 응답이 나온다.

### 5.3 파일 분할

`jsonapi_query.rb`는 549줄에 `RawQuery` · `ShapeTree` · `Parser` 세 클래스가 들어 있다. cursor를 얹으면 700줄을 넘는다. NestJS가 이미 같은 선을 그었다.

```text
app/controllers/concerns/jsonapi_query.rb   concern 진입점과 액션별 검증 (~130줄)
app/lib/jsonapi/raw_query.rb                RawQuery + ShapeTree
app/lib/jsonapi/query_parser.rb             파싱과 scope 적용
app/lib/jsonapi/pagination.rb               offset · probe · 링크 조립
app/lib/jsonapi/cursor.rb                   커서 인코딩·디코딩, keyset 술어
```

Rails는 `app/*` **각각을** Zeitwerk 루트로 등록한다(`paths.add "app", glob: "{*,*/concerns}"`). 따라서 `app/jsonapi/raw_query.rb`는 최상위 `RawQuery`를 정의해야 하고, `Jsonapi::RawQuery`를 넣으면 `NameError`가 난다 — 저장소 안의 증거는 `app/errors/json_api_error.rb`가 최상위 `JsonApiError`를 정의한다는 것이다. `app/lib`는 그 자체가 루트이므로 `app/lib/jsonapi/raw_query.rb` → `Jsonapi::RawQuery`가 설정 한 줄 없이 성립한다. 덤으로 SimpleCov의 `track_files "app/**/*.rb"`에도 걸린다 — 최상위 `lib/`에 두었다면 커버리지 추적에서 조용히 빠졌을 자리다.

## 6. 단계 3 — 인증 이식

### 6.1 스키마

```text
users             id(uuid) · email(varchar 254, unique) · password_hash(text)
                  is_active(bool) · created_at · updated_at

refresh_sessions  id(uuid)                        = refresh JWT의 jti
                  user_id(FK users ON DELETE CASCADE)
                  token_hash(varchar 64, unique)  = SHA-256(raw refresh JWT)
                  expires_at · revoked_at(nullable)
                  replaced_by_id(FK self ON DELETE SET NULL)
                  created_at
```

`replaced_by_id`에 인덱스를 만든다 — 근거는 6.6에 있다.

### 6.2 토큰

access와 refresh 둘 다 JWT이고 claims가 같다: `sub`(user id) · `jti` · `type`(`access` / `refresh`) · `iat` · `exp` · `iss` · `aud`.

`refresh_sessions.id`가 refresh JWT의 `jti`와 같다 — 이것이 세션과 토큰의 연결점이다. 조회 키는 `token_hash`(unique)다.

저장 해시가 SHA-256인 것은 토큰이 이미 고엔트로피이기 때문이다. 느린 해시가 필요 없다. 비교는 상수 시간으로 한다.

### 6.3 비밀번호

argon2를 쓴다. `argon2` gem을 추가한다.

bcrypt는 Gemfile에 이미 있지만 **72바이트에서 잘라낸다.** 계약상 비밀번호가 12~128자이므로, bcrypt를 쓰면 73바이트부터 다른 두 비밀번호가 모두 로그인에 성공하는 상태가 조용히 생긴다. 사전 SHA-256 압축으로 우회할 수는 있으나 그 보정 자체가 다른 두 백엔드에 없는 코드가 된다.

### 6.4 회전 — 재사용 감지

```text
이미 폐기된 세션으로 회전을 시도하면
  → 그 사용자의 활성 세션을 전부 폐기하고 401 TOKEN_REVOKED
```

훔친 refresh token이 쓰였다는 신호이므로 해당 세션 하나가 아니라 그 사용자의 모든 세션을 끊는다.

정상 회전은 한 트랜잭션 안에서 일어난다.

```text
1. 사용자 행을 잠근다 (SELECT ... FOR UPDATE)
2. 옛 세션에 revoked_at
3. 새 세션 생성 + 새 토큰 쌍 발급
4. 옛 세션의 replaced_by_id = 새 세션 id
```

폐기와 생성이 갈라지면 로그인은 되는데 갱신은 안 되는 상태가 남는다.

비활성 사용자로 회전하면 그 세션만 폐기하고 403 `USER_INACTIVE`다. 로그아웃은 멱등하다 — `revoked_at ||= now`.

### 6.5 로그인의 순서는 계약이다

```text
1. 이메일이 없어도 argon2 검증을 한 번 돌린다 (dummy 해시)
     즉시 반환하면 응답 시간이 "그 계정은 없다"를 알려 준다
2. 비밀번호를 먼저 검증하고 활성 여부를 나중에 본다
     순서를 뒤집으면 비밀번호를 모르는 사람이 USER_INACTIVE와
     INVALID_CREDENTIALS의 차이로 계정 존재를 알아낸다
```

### 6.6 정리 job

`PurgeExpiredRefreshSessionsJob`(Sidekiq)이 `REFRESH_SESSION_RETENTION_SECONDS`가 지난 만료 세션을 배치로 삭제한다.

`replaced_by_id`가 자기 참조 FK(`ON DELETE SET NULL`)이므로 대량 삭제가 cascade UPDATE를 유발한다. NestJS가 이 지점에서 실제로 사고를 냈다 — 인덱스가 없어 배치마다 전체 테이블을 순차 스캔했다. 배치 상한도 잠금 대기 상한도 이를 막지 못했다. 하나는 왕복 횟수의 상한이고 하나는 잠금 **대기**의 상한이지, 둘 다 문장 **실행 시간**의 상한이 아니기 때문이다.

`(replaced_by_id)` 인덱스를 스키마 마이그레이션과 같은 변경에 넣고, 문장 실행 시간 상한을 건다.

### 6.7 가입 중복

사전 조회로 막지 않는다 — 조회와 삽입 사이에 다른 요청이 들어오면 둘 다 통과한다. 유니크 제약이 실제로 막게 두고 그 오류만 409 `EMAIL_ALREADY_REGISTERED`로 옮긴다.

지금 `jsonapi_errors.rb`가 `ActiveRecord::RecordNotUnique`를 일괄로 `RESOURCE_CONFLICT`에 매핑한다. `AuthController`가 가입 경로에서 그 예외를 먼저 잡아 변환한다.

### 6.8 `AuthController`는 `CrudActions`를 쓰지 않는다

자원 하나의 CRUD가 아니라 서로 다른 네 동작이고, 요청과 응답의 자원 타입이 다르다(`users` → `users`, `authCredentials` → `authTokens`, `refreshTokens` → `authTokens`). 문서 파싱과 응답 조립은 같은 헬퍼를 쓰므로 오류 모양은 CRUD 라우트와 어긋나지 않는다.

### 6.9 추가와 제거

추가:

```text
app/models/user.rb · refresh_session.rb
app/auth/passwords.rb · tokens.rb · refresh_sessions.rb
app/controllers/concerns/jsonapi_authentication.rb
app/controllers/api/v1/auth_controller.rb · users_controller.rb
app/serializers/user_serializer.rb · auth_token_serializer.rb
app/jobs/purge_expired_refresh_sessions_job.rb
db/migrate/..._create_auth_schema.rb
```

제거:

```text
app/services/auth_service_client.rb            서킷 브레이커 포함
app/models/auth_user.rb                        workspace 모델
ApiController의 enterprise_check! · personal_check! · user_check!
docker-compose.yml의 auth-stub(WireMock) 서비스와 docker/ 설정
AUTH_SERVICE_URL 환경변수
오류 코드 FORBIDDEN · AUTH_SERVICE_UNAVAILABLE (ko · en 양쪽)
```

`Current.user`는 유지하되 타입이 `AuthUser` → `User`로 바뀐다.

### 6.10 오류 카탈로그

`config/locales/jsonapi.{ko,en}.yml`에 6개를 추가한다.

```text
EMAIL_ALREADY_REGISTERED · INVALID_CREDENTIALS · INVALID_TOKEN
TOKEN_EXPIRED · TOKEN_REVOKED · USER_INACTIVE
```

기존 20개 중 18개는 이미 정본과 같다.

## 7. 단계 4 — `categories` · `tags` 읽기 라우트

계약은 Next.js 스펙 6장이 소유한다. 여기서는 Rails 반영만 정한다.

```text
GET /api/v1/categories · /api/v1/categories/{id}
GET /api/v1/tags       · /api/v1/tags/{id}
```

```ruby
def query_contract
  {
    filters:  { "name" => { attribute: :name, type: :string, operators: %w[exact contains] } },
    sorts:    { "name"      => { attribute: :name,       nullable: false },
                "createdAt" => { attribute: :created_at, nullable: false } },
    includes: [],
    default_sort: [ { field: "name", direction: :asc } ],
    tie_breaker:  { field: "id", direction: :asc }
  }
end
```

`CrudActions`에 읽기 전용 옵션을 추가해 쓰기 라우트와 관계 라우트를 등록하지 않는다.

**새 인덱스를 만들지 않는다.** 다만 근거가 "기존 인덱스로 커버된다"가 아니다 — PostgreSQL은 유니크 제약을 근거로 뒤따르는 정렬 키를 지우지 않으므로 `ORDER BY name, id` 계획에는 incremental sort가 남는다. 만들지 않는 실제 이유는 `name`이 유니크해서 동점 그룹의 크기가 항상 1이라 그 정렬 단계가 실질적으로 하는 일이 없고, 참조 테이블의 행 수가 작다는 것이다(분류·라벨 각각 수십 개 규모). 행 수가 크게 늘어 이 목록이 주된 부하가 되면 그때 `(name, id)`를 같은 규칙으로 판단해 추가한다. "정렬을 여는 변경은 인덱스를 진다"는 규칙이 요구하는 것은 인덱스 자체가 아니라 이 판단의 기록이므로, 위 근거를 각 백엔드의 정책 선언부 주석에 남긴다. 정렬이 인덱스로 완전히 커버됨을 EXPLAIN으로 고정하는 테스트(FastAPI의 `test_query_indexes.py`)를 이 자원에 복사하지 않는다 — 여기서는 그 단언이 참이 아니다.

시리얼라이저에 `self` 링크가 생기므로 `include=category,tags` 응답의 `included[]`가 바뀐다. 같은 변경에서 기존 spec의 기대값을 갱신한다.

## 8. 설정과 환경 변수

필수 변수에는 애플리케이션 코드상의 암묵적 기본값을 두지 않는다. 누락하면 변수 이름이 담긴 오류와 함께 시작에 실패한다.

| 변수 | 필수 | 비고 |
| --- | --- | --- |
| `JWT_SECRET_KEY` | 예 | UTF-8 기준 최소 32바이트 |
| `JWT_ACCESS_EXPIRES_SECONDS` | 아니오 | 기본 900 |
| `JWT_REFRESH_EXPIRES_SECONDS` | 아니오 | 기본 2592000 |
| `JWT_ISSUER` · `JWT_AUDIENCE` | 아니오 | 기본 `template-ruby-rails` |
| `REFRESH_SESSION_RETENTION_SECONDS` | 아니오 | 정리 job의 보존 기간 |

제거: `AUTH_SERVICE_URL`. 유지: `CORS_ALLOWED_ORIGINS`(1.3).

## 9. 검증

기존 RSpec · RuboCop · Brakeman · SimpleCov 게이트에 더한다.

| 단계 | 검증 |
| --- | --- |
| 1 | 기존 request spec이 한 바이트도 다르지 않다 (순수 리팩터링) |
| 2 | probe · `page[totals]` · cursor 순회 · nullable 정렬 거부 · `page[number]`와 커서 동시 사용 거부 |
| 3 | 회전 · **재사용 감지(전 세션 폐기)** · 타이밍 순서 · 멱등 로그아웃 · 만료 토큰 · 비활성 사용자 |
| 4 | 두 자원의 목록·단건·필터·정렬, 쓰기 라우트가 404인 것 |
| 전체 | **정본과의 응답 대조** — 같은 요청에 같은 문서가 나오는가 |

마지막 항목이 이 작업의 진짜 완료 조건이다. 나머지는 그 조건에 도달하기 위한 중간 확인이다.

## 10. 리스크

| 리스크 | 대응 |
| --- | --- |
| 단계 1이 의도치 않게 응답을 바꾼다 | 기존 request spec 전체가 안전망. 실패하면 그 자리에서 멈춘다 |
| 재사용 감지를 빠뜨린다 | 가장 놓치기 쉬운 부분이다. 단계 3의 필수 spec으로 고정한다 |
| 정리 job의 cascade UPDATE | `(replaced_by_id)` 인덱스 + 문장 실행 시간 상한 (6.6) |
| workspace 제거가 다른 곳을 건드린다 | `AuthUser` · `enterprise_check!` 참조를 먼저 전수 조사한다 |
| 정본과의 대조가 수작업이 된다 | 같은 요청 집합을 두 스택에 던져 문서를 비교하는 스크립트를 단계 2에서 만들어 이후 단계마다 재사용한다 |
| argon2 gem이 빌드 환경에 없다 | Dockerfile 빌드 단계에서 먼저 확인한다 |
