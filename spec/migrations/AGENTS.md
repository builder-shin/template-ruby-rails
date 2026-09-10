<!-- Parent: ../AGENTS.md -->
<!-- Generated: 2026-09-11 | Updated: 2026-09-11 -->

# spec/migrations

## Purpose

Replays initial domain/auth migrations into temporary PostgreSQL schemas and checks schema metadata and actual database behavior.

## Key Files

| File | Description |
|------|-------------|
| `create_example_schema_spec.rb` | Checks UUID defaults, Example constraints, reference names, taggings keys/cascades, timestamps, and rollback. |
| `create_auth_schema_spec.rb` | Checks auth columns/indexes/foreign keys, app-supplied refresh UUIDs, deletion behavior, rollback, and the current test database's ID defaults. |

## For AI Agents

### Working In This Directory

- Retain unique temporary schema and connection-class names, separate connections, and ensure-based schema/connection/constant cleanup.
- Use real inserts/deletes to verify constraints and cascading behavior; metadata assertions alone cover a different part of the contract.
- Keep the current-database assertion for refresh-session ID defaults: migration replay alone cannot detect drift in `db/schema.rb`.
- Preserve the deliberate absence of a refresh-session database ID default.

### Testing Requirements

Run `bundle exec rspec spec/migrations` from the repository root with the environment described in `../AGENTS.md`. A focused run may set `COVERAGE_MINIMUM=0`; retain the default gate for the final full suite. The database user must be able to create/drop schemas. CI creates the test database with `db:schema:load`, while these specs additionally replay migrations in isolated schemas.

## Dependencies

Internal: `../rails_helper.rb`, migration files `db/migrate/20260201000000_create_example_schema.rb` and `db/migrate/20260205000000_create_auth_schema.rb`, and the active test database. External: PostgreSQL, ActiveRecord, RSpec Rails, and SecureRandom.

<!-- MANUAL: Any manually added notes below this line are preserved on regeneration -->
