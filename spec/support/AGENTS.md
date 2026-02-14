<!-- Parent: ../AGENTS.md -->
<!-- Generated: 2026-02-14 | Updated: 2026-02-14 -->

# support

## Purpose
RSpec 테스트 공통 헬퍼와 설정 파일.

## Key Files

| File | Description |
|------|-------------|
| `auth_helper.rb` | 인증 테스트 헬퍼 (AuthServiceClient 스텁, 테스트용 사용자 생성) |
| `jsonapi_errors_patch.rb` | JSON:API 에러 응답 패치 |

## For AI Agents

### Working In This Directory
- 테스트에서 인증이 필요하면 `auth_helper.rb`의 메서드 사용
- 공통 설정/헬퍼를 여기에 추가하고 `rails_helper.rb`에서 require

<!-- MANUAL: -->
