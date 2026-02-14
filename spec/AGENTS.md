<!-- Parent: ../AGENTS.md -->
<!-- Generated: 2026-02-14 | Updated: 2026-02-14 -->

# spec

## Purpose
RSpec 테스트 스위트. 서비스 객체 테스트와 테스트 헬퍼/서포트 파일을 포함한다.

## Key Files

| File | Description |
|------|-------------|
| `rails_helper.rb` | RSpec Rails 설정 |
| `swagger_helper.rb` | Rswag Swagger 테스트 헬퍼 |

## Subdirectories

| Directory | Purpose |
|-----------|---------|
| `services/` | 서비스 객체 테스트 (see `services/AGENTS.md`) |
| `support/` | 테스트 헬퍼 및 공통 설정 (see `support/AGENTS.md`) |

## For AI Agents

### Working In This Directory
- `bundle exec rspec` 으로 전체 테스트 실행
- 새 테스트 파일은 해당 소스 디렉토리 구조를 미러링하여 생성
- FactoryBot, Shoulda Matchers, WebMock, DatabaseCleaner 사용 가능

### Testing Requirements
- 외부 API 호출은 WebMock으로 스텁 처리
- 인증이 필요한 테스트는 `spec/support/auth_helper.rb` 참조

<!-- MANUAL: -->
