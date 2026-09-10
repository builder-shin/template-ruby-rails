<!-- Parent: ../AGENTS.md -->
<!-- Generated: 2026-09-11 | Updated: 2026-09-11 -->

# migrate

## Purpose

Ordered Active Record migrations defining the Example domain, Active Storage tables, and local user/refresh-session persistence.

## Key Files

| File | Description |
|------|-------------|
| `20260201000000_create_example_schema.rb` | Rails 8.1 migration for UUID examples/categories/tags, composite taggings, constraints, and delete actions. |
| `20260204100001_create_active_storage_tables.active_storage.rb` | Imported Rails 7.0 migration creating blob, attachment, and variant tables; attachment record references are explicitly UUID. |
| `20260205000000_create_auth_schema.rb` | Rails 8.1 migration for users and refresh sessions, unique email/token hashes, expiry/self-reference indexes, and auth foreign keys. |

## For AI Agents

### Working In This Directory

- Preserve the declared migration versions and chronological filenames. New schema changes should use migrations and regenerate `db/schema.rb`.
- Keep Example status limited to `draft`, `active`, and `archived`, score within 0..100, and title length at 200 unless intentionally changing the application contract too.
- Category deletion nullifies `examples.category_id`; deleting examples/tags cascades through the composite-key tagging table.
- Refresh-session IDs must remain UUIDs with explicit `default: nil`, supplied by application JWT issuance. Users retain generated UUID IDs.
- Keep `user_id`, `expires_at`, and `replaced_by_id` indexes in the auth schema. The self-reference nullifies on replacement deletion, and user deletion cascades sessions.
- Preserve UUID Active Storage attachment `record_id` while allowing blob/variant keys to follow the migration's configured numeric key types.

### Testing Requirements

Run `bundle exec rspec spec/migrations` against PostgreSQL using the root environment instructions. The specs create isolated schemas, apply each domain migration, inspect constraints/indexes, exercise invalid inserts and foreign-key deletion effects, and test rollback. The auth spec additionally inspects actual test database defaults so schema-load drift is detected.

### Common Patterns

Migrations use reversible `change` methods, database-enforced uniqueness/check constraints, and explicit foreign-key deletion semantics. The Active Storage migration separately derives blob key types from Rails generator configuration.

## Dependencies

### Internal

`db/schema.rb` is the generated snapshot; models and auth/session jobs in `app/` depend on these types and indexes; `spec/migrations/` provides behavioral checks.

### External

Active Record migration APIs, PostgreSQL, and Active Storage.

<!-- MANUAL: Any manually added notes below this line are preserved on regeneration -->
