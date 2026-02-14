<!-- Parent: ../AGENTS.md -->
<!-- Generated: 2026-02-14 | Updated: 2026-02-14 -->

# lib

## Purpose
라이브러리 코드와 커스텀 Rake 태스크를 포함한다.

## Subdirectories

| Directory | Purpose |
|-----------|---------|
| `tasks/` | 커스텀 Rake 태스크 |
| `assets/` | 라이브러리 에셋 (현재 미사용) |

## Key Files

| File | Description |
|------|-------------|
| `tasks/fdw.rake` | PostgreSQL Foreign Data Wrapper 관련 Rake 태스크 |
| `tasks/migrate_data.rake` | 데이터 마이그레이션 Rake 태스크 |

## For AI Agents

### Working In This Directory
- 새 Rake 태스크는 `lib/tasks/` 아래에 `.rake` 파일로 생성
- `bin/rails` 또는 `bundle exec rake` 로 실행

<!-- MANUAL: -->
