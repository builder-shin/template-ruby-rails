<!-- Parent: ../AGENTS.md -->
<!-- Generated: 2026-09-11 | Updated: 2026-09-11 -->

# spec/models

## Purpose

Model contracts for Example domain records and authentication persistence.

## Key Files

| File | Description |
|------|-------------|
| `example_spec.rb` | Tests title/status/score validation and a UUID-backed base factory without implicit relationships. |
| `example_relationships_spec.rb` | Tests deterministic tag order, associations, cascade/nullify behavior, name/pair validation, and factory traits. |
| `user_spec.rb` | Tests presence, database-only email uniqueness, dependent sessions, and user defaults. |
| `refresh_session_spec.rb` | Tests database-only token-hash uniqueness, absence of a pre-insert SELECT, associations, and explicit UUID factory defaults. |

## For AI Agents

### Working In This Directory

- Keep SQL-backed uniqueness tests for users and refresh sessions; model uniqueness preflight is intentionally absent.
- Preserve fixtures that separate UUID order, name order, and attachment order.
- Use database `.delete` operations in cascade tests so callbacks cannot substitute for foreign-key behavior.
- Check that unsupported Example status assignment succeeds and validation rejects it, preserving the controller's 422 behavior.

### Testing Requirements

Run `bundle exec rspec spec/models` from the repository root with the environment described in `../AGENTS.md`. A focused run may set `COVERAGE_MINIMUM=0`; retain the default gate for the final full suite.

## Dependencies

Internal: `../rails_helper.rb`, factories, `Example`, `ExampleCategory`, `ExampleTag`, `ExampleTagging`, `User`, and `RefreshSession`. External: RSpec Rails, ActiveRecord notifications, FactoryBot, and PostgreSQL.

<!-- MANUAL: Any manually added notes below this line are preserved on regeneration -->
