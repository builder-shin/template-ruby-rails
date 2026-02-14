<!-- Parent: ../AGENTS.md -->
<!-- Generated: 2026-02-14 | Updated: 2026-02-14 -->

# db

## Purpose
데이터베이스 스키마 정의, 마이그레이션, 시드 데이터. PostgreSQL 기반이며 UUID PK, postgres_fdw, uuid-ossp 확장을 사용한다.

## Key Files

| File | Description |
|------|-------------|
| `schema.rb` | 현재 DB 스키마 (자동 생성, 직접 수정 금지) |
| `seeds.rb` | 시드 데이터 |

## Subdirectories

| Directory | Purpose |
|-----------|---------|
| `migrate/` | ActiveRecord 마이그레이션 파일들 (see `migrate/AGENTS.md`) |

## For AI Agents

### Working In This Directory
- `schema.rb`를 직접 수정하지 말 것 — 마이그레이션 생성 후 `bin/rails db:migrate` 실행
- UUID PK 사용: `id: :uuid, default: -> { "uuid_generate_v4()" }`
- 레거시 TypeORM 테이블명(단수형, snake_case)이 혼재 — 새 테이블은 Rails 컨벤션(복수형) 사용
- `typeorm_metadata`, `migrations_history`, `query-result-cache` 테이블은 레거시이므로 무시

### Key Schema Notes
- 30+ 테이블: profiles, job_posts, career_hub_*, blog_* 등
- 복합 PK 테이블: `job_post_categories`, `job_post_jobs`, `profile_jobs`, `blog_post_category`
- Active Storage 테이블 포함 (`active_storage_*`)

<!-- MANUAL: -->
