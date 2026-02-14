<!-- Parent: ../AGENTS.md -->
<!-- Generated: 2026-02-14 | Updated: 2026-02-14 -->

# services

## Purpose
서비스 객체 RSpec 테스트.

## Key Files

| File | Description |
|------|-------------|
| `auth_service_client_spec.rb` | AuthServiceClient 테스트 (Circuit Breaker, 세션 검증) |

## For AI Agents

### Working In This Directory
- 서비스 테스트 파일명: `{service_name}_spec.rb`
- 외부 API 호출은 WebMock으로 스텁 처리 필수
- `spec/support/auth_helper.rb`의 인증 헬퍼 활용

<!-- MANUAL: -->
