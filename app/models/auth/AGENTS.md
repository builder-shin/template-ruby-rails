<!-- Parent: ../AGENTS.md -->
<!-- Generated: 2026-02-14 | Updated: 2026-02-14 -->

# auth

## Purpose
외부 Auth 데이터베이스의 읽기 전용 모델. PostgreSQL Foreign Data Wrapper(FDW)를 통해 인증 서비스 DB에 접근한다. `Auth::` 네임스페이스를 사용한다.

## Key Files

| File | Description |
|------|-------------|
| `base.rb` | Auth 모델 베이스 클래스 (FDW 연결 설정) |
| `user.rb` | Auth 사용자 모델 (읽기 전용) |
| `user_consent.rb` | 사용자 동의 정보 |
| `workspace.rb` | 워크스페이스 모델 |
| `workspace_member.rb` | 워크스페이스 멤버 모델 |

## For AI Agents

### Working In This Directory
- **읽기 전용** — 이 모델들로 데이터를 수정하지 말 것
- `Auth::Base` 상속 필수 (ApplicationRecord가 아님)
- FDW 테이블이므로 마이그레이션으로 스키마를 변경할 수 없음
- `?include=user` 등으로 JSON:API include 시 사용됨

<!-- MANUAL: -->
