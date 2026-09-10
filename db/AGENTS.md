<!-- Parent: ../AGENTS.md -->
<!-- Generated: 2026-09-11 | Updated: 2026-09-11 -->

# db

## Purpose

PostgreSQL schema history, the generated schema snapshot, and repeatable reference-data seeds for the Example domain and local authentication. Active Storage tables share this database.

## Key Files

| File | Description |
|------|-------------|
| `schema.rb` | Rails 8.1 schema snapshot at version `2026_02_05_000000`, containing Example, auth, and Active Storage tables and constraints. |
| `seeds.rb` | Finds or creates both categories and tags named General, Ruby, and API. |

## Subdirectories

| Directory | Purpose |
|-----------|---------|
| [migrate/](migrate/AGENTS.md) | Example, Active Storage, and authentication migrations. |

## For AI Agents

### Working In This Directory

- Change schema through migrations and regenerate `schema.rb`; its header explicitly identifies it as generated. Keep the snapshot tracked because Rails can initialize databases with `db:schema:load`.
- Preserve UUID domain/user identifiers, the composite tagging primary key, check constraints, and foreign-key delete behavior.
- `refresh_sessions.id` deliberately has `default: nil`; the application must provide the refresh JWT's `jti`. Removing that option silently restores the PostgreSQL adapter's UUID default.
- Keep `refresh_sessions` indexes on `user_id`, `expires_at`, and `replaced_by_id`; they support deletion cascades, expiry selection, and self-reference nullification.
- Preserve repeatable seed behavior using `find_or_create_by!` and the same names for categories and tags.

### Testing Requirements

- Use the root PostgreSQL/test environment instructions and `bin/rails db:prepare` for local preparation.
- For schema changes, run `bundle exec rspec spec/migrations` and the affected model/request specs. The migration specs exercise fresh PostgreSQL schemas and rollback; the auth spec also inspects the actual test database's ID defaults.
- Verify both migration execution and schema-loaded databases retain the intended refresh-session primary key behavior.

### Common Patterns

Most domain tables use generated UUIDs and non-null timestamps. Refresh sessions use an application-supplied UUID and only `created_at`; Active Storage blobs and variant records retain numeric keys while attachment `record_id` is UUID.

## Dependencies

### Internal

`config/database.yml` selects the database; Example/auth models consume these tables; `PurgeExpiredRefreshSessionsJob` relies on expiry and self-reference indexes; `spec/migrations/` verifies constraints and reversibility.

### External

Active Record, PostgreSQL with `gen_random_uuid()`, and Active Storage.

<!-- MANUAL: Any manually added notes below this line are preserved on regeneration -->
