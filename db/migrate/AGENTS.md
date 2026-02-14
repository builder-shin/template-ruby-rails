<!-- Parent: ../AGENTS.md -->
<!-- Generated: 2026-02-14 | Updated: 2026-02-14 -->

# migrate

## Purpose
ActiveRecord 데이터베이스 마이그레이션 파일. TypeORM에서 Rails 컨벤션으로 전환된 스키마와 이후 추가된 테이블/인덱스를 관리한다.

## Key Files

| File | Description |
|------|-------------|
| `20260201134935_convert_to_rails_conventions.rb` | TypeORM → Rails 컨벤션 전환 마이그레이션 |
| `20260204100000_setup_active_storage_for_attachments.rb` | Active Storage 설정 |
| `20260204100001_create_active_storage_tables.active_storage.rb` | Active Storage 테이블 생성 |
| `20260205161903_create_recruitment_requests.rb` | 채용 의뢰 테이블 생성 |
| `20260207140000_add_missing_filter_indexes.rb` | 필터 관련 인덱스 추가 |

## For AI Agents

### Working In This Directory
- 새 마이그레이션: `bin/rails generate migration MigrationName`
- UUID PK: `create_table :name, id: :uuid, default: -> { "uuid_generate_v4()" }`
- 실행: `bin/rails db:migrate`
- 롤백: `bin/rails db:rollback`

<!-- MANUAL: -->
