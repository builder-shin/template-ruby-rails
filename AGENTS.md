<!-- Generated: 2026-02-14 | Updated: 2026-02-14 -->

# template-ruby-rails

## Purpose
Rails 8.1 기반 JSON:API 백엔드 템플릿 프로젝트. 채용 플랫폼(구인/구직, 프로필, 블로그, 커리어 허브 커뮤니티)의 API 서버로, 외부 Auth 서비스와 연동하는 쿠키 기반 인증을 사용한다.

## Key Files

| File | Description |
|------|-------------|
| `Gemfile` | 프로젝트 의존성 (Rails 8.1, jsonapi.rb, Sidekiq, Faraday 등) |
| `Rakefile` | Rake 태스크 진입점 |
| `README.md` | 프로젝트 소개 문서 |
| `.rubocop.yml` | RuboCop 스타일 설정 |

## Subdirectories

| Directory | Purpose |
|-----------|---------|
| `app/` | 애플리케이션 소스 코드 (see `app/AGENTS.md`) |
| `config/` | Rails 설정 및 초기화 (see `config/AGENTS.md`) |
| `db/` | 데이터베이스 스키마, 마이그레이션, 시드 (see `db/AGENTS.md`) |
| `spec/` | RSpec 테스트 (see `spec/AGENTS.md`) |
| `lib/` | 라이브러리 및 Rake 태스크 (see `lib/AGENTS.md`) |

## For AI Agents

### Working In This Directory
- JSON:API 스펙(`jsonapi.rb` + `jsonapi-serializer`) 준수 필수
- 쿠키 기반 인증: `request.cookies['session_web']` → `AuthServiceClient` → `Current.user`
- Guard clause 패턴 필수, if/elsif/else 금지
- 한국어 에러 메시지 사용
- Flat 디렉토리 구조 유지 (최대 2-3단계)

### Testing Requirements
- `bundle exec rspec` 으로 테스트 실행
- RSpec + FactoryBot + Shoulda Matchers 사용

### Common Patterns
- `ApiController` 상속 → `CrudActions` concern 자동 포함
- `ApplicationSerializer` 상속으로 JSON:API 시리얼라이저 생성
- `ApplicationRecord` 상속으로 모델 생성 (Ransack 전체 허용, 필터는 컨트롤러에서 제어)
- 환경 변수: `AUTH_SERVICE_URL`, `DATABASE_URL`, `SECRET_KEY_BASE`

## Dependencies

### External
- Rails 8.1 - 웹 프레임워크
- PostgreSQL - 데이터베이스 (`pg` gem)
- jsonapi.rb + jsonapi-serializer - JSON:API 스펙
- Sidekiq + sidekiq-cron - 백그라운드/스케줄 작업
- Faraday - HTTP 클라이언트 (외부 Auth 서비스 연동)
- Ransack - 검색/필터링
- Kaminari - 페이지네이션
- Active Storage + AWS S3 - 파일 업로드
- SendGrid - 이메일 발송
- Sentry - 에러 트래킹

<!-- MANUAL: -->
