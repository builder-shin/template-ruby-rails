<!-- Generated: 2026-02-06 -->

# Template Ruby Rails

## Purpose
Rails 8 기반 JSON:API 백엔드 템플릿. PostgreSQL 데이터베이스를 사용하며, JSON:API 스펙 준수 응답을 제공합니다. 외부 인증 서비스와 연동하여 쿠키 기반 세션 인증을 처리합니다.

## Key Files
| File | Description |
|------|-------------|
| `CLAUDE.md` | Rails 프로젝트 가이드 및 코드 컨벤션 |
| `Gemfile` | Ruby 의존성 정의 (Rails 8.1, jsonapi.rb, Sidekiq 등) |
| `config.ru` | Rack 설정 파일 |
| `Rakefile` | Rake 태스크 정의 |
| `README.md` | 프로젝트 개요 및 디렉토리 구조 |
| `.env` | 환경 변수 (gitignore됨) |
| `.rubocop.yml` | Ruby 코드 스타일 설정 |

## Subdirectories
| Directory | Purpose |
|-----------|---------|
| `app/` | Rails 애플리케이션 코드 (controllers, models, serializers, services 등) (see `app/AGENTS.md`) |
| `config/` | Rails 설정 파일 (database.yml, routes.rb, initializers 등) (see `config/AGENTS.md`) |
| `db/` | 데이터베이스 마이그레이션 및 스키마 (see `db/AGENTS.md`) |
| `spec/` | RSpec 테스트 파일 |
| `test/` | Minitest 테스트 파일 (기본 Rails 테스트) |
| `lib/` | 커스텀 라이브러리 및 Rake 태스크 |
| `bin/` | 실행 스크립트 (rails, rake, bundle 등) |
| `public/` | 정적 파일 (에러 페이지, favicon 등) |
| `log/` | 로그 파일 |
| `tmp/` | 임시 파일 (캐시, PID 파일 등) |
| `storage/` | Active Storage 업로드 파일 (개발 환경) |
| `docs/` | 프로젝트 문서 |
| `scripts/` | 유틸리티 스크립트 |

## For AI Agents

### Working In This Directory
Rails API 프로젝트 루트에서 작업할 때:

1. **환경 확인**: Ruby 3.4.0, Rails 8.1.2, PostgreSQL 사용 확인
2. **CLAUDE.md 필독**: 코드 컨벤션, 인증 패턴, flat 디렉토리 구조 규칙 숙지
3. **JSON:API 스펙**: jsonapi.rb + jsonapi-serializer 사용, 모든 응답은 JSON:API 형식
4. **인증**: 외부 Auth 서비스 연동, 쿠키 기반 세션 (session_web)
5. **네이밍 규칙**: Association 이름 = 시리얼라이저 관계명 = 파일명(테이블명) 기준

### Common Patterns

#### 서버 실행
```bash
# 개발 서버 (포트 4000)
bin/rails server
```

#### 데이터베이스 작업
```bash
# 마이그레이션 실행
bin/rails db:migrate

# 롤백
bin/rails db:rollback

# 스키마 로드
bin/rails db:schema:load

# 데이터베이스 초기화
bin/rails db:reset
```

#### 콘솔 및 테스트
```bash
# Rails 콘솔
bin/rails console

# RSpec 테스트
bundle exec rspec

# 특정 파일 테스트
bundle exec rspec spec/models/profile_spec.rb
```

#### 새 리소스 생성 워크플로우
1. **마이그레이션 생성**: `bin/rails g migration CreateResources`
2. **모델 생성**: `app/models/resource.rb` (ApplicationRecord 상속)
3. **시리얼라이저 생성**: `app/serializers/resource_serializer.rb`
4. **컨트롤러 생성**: `app/controllers/api/v1/resources_controller.rb` (CrudActions include)
5. **라우트 추가**: `config/routes.rb`에 `resources :resources` 추가
6. **마이그레이션 실행**: `bin/rails db:migrate`

#### Flat 디렉토리 규칙
- 디렉토리 중첩 최대 2-3단계
- `app/controllers/api/v1/` 네임스페이스 아래 모든 컨트롤러 배치
- 과도한 하위 폴더 생성 금지

#### Guard Clause 패턴 (필수)
- **if/elsif/else 패턴 금지** — guard clause (early return/raise) 사용
- 조건 불일치 시 `raise` 또는 `return`으로 먼저 빠져나가고, 정상 흐름을 아래에 배치
- 반복문 내에서는 `next` 사용
- `case/when/else`는 허용 (switch-case 패턴)

```ruby
# ✅ Good
def verify_ownership!
  return if @model.user_id == user_info.id

  raise JsonApiError.new("Forbidden", "자신의 리소스만 수정할 수 있습니다.", 403)
end

# ❌ Bad
def verify_ownership!
  if @model.user_id == user_info.id
    # pass
  else
    raise JsonApiError.new("Forbidden", "자신의 리소스만 수정할 수 있습니다.", 403)
  end
end
```

#### Association/Serializer 관계명 규칙
- **모델 association 이름 = 시리얼라이저 relationship 이름 = 파일명(테이블명) 기준**
- `class_name`은 자기 참조, 역할 alias, 다른 네임스페이스 등 추론 불가 시에만 사용
- FK 컬럼명이 `#{관계명}_id`와 다르면 모델에 `foreign_key:`, 시리얼라이저에 `id_method_name:` 명시

```ruby
# Good - 파일명 기준
belongs_to :career_hub_community, foreign_key: :community_id
has_many :career_hub_community_events, foreign_key: :community_id

# Bad - 축약 이름
belongs_to :community, class_name: 'CareerHubCommunity'
```

#### JSON:API 요청 예시
```bash
# include 파라미터로 관계 포함
GET /api/v1/profiles?include=job_category,profile_experiences

# 필터링
GET /api/v1/profiles?filter[job_seeking_status]=actively_seeking

# 페이지네이션
GET /api/v1/profiles?page[number]=2&page[size]=20
```

## Dependencies

### Internal
- `app/` - 애플리케이션 로직
- `config/` - 설정 파일
- `db/` - 데이터베이스 스키마

### External
| Gem | 용도 |
|-----|------|
| `rails (8.1.2)` | 웹 프레임워크 |
| `pg` | PostgreSQL 어댑터 |
| `puma` | 웹 서버 |
| `jsonapi.rb` | JSON:API 스펙 구현 |
| `jsonapi-serializer` | JSON:API 시리얼라이저 |
| `kaminari` | 페이지네이션 |
| `ransack` | 검색 및 필터링 |
| `faraday` | HTTP 클라이언트 (외부 API 호출) |
| `sidekiq` | 백그라운드 작업 |
| `rack-cors` | CORS 설정 |
| `bcrypt` | 비밀번호 암호화 |
| `aws-sdk-s3` | Active Storage S3 연동 |
| `rspec-rails` | 테스트 프레임워크 |
| `factory_bot_rails` | 테스트 데이터 생성 |
| `faker` | 무작위 데이터 생성 |
| `dotenv-rails` | 환경 변수 관리 |
| `sentry-rails` | 에러 트래킹 |

<!-- MANUAL: -->
