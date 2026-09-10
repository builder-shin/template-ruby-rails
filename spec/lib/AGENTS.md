<!-- Parent: ../AGENTS.md -->
<!-- Generated: 2026-09-11 | Updated: 2026-09-11 -->

# spec/lib

## Purpose

Library contract specs grouped by the application's Auth and Jsonapi namespaces.

## Subdirectories

| Directory | Purpose |
|-----------|---------|
| [auth/](auth/AGENTS.md) | Password hashing, JWT claims, refresh rotation and transaction contracts. |
| [jsonapi/](jsonapi/AGENTS.md) | Cursor serialization and query parser cursor-mode constraints. |

## For AI Agents

### Working In This Directory

- Keep HTTP endpoint behavior under `spec/requests`; use these groups for library inputs, return values, exceptions, and transaction contracts.
- Follow each child's guidance for database/cryptographic setup.

### Testing Requirements

Run `bundle exec rspec spec/lib` from the repository root with the environment described in `../AGENTS.md`. A focused run may set `COVERAGE_MINIMUM=0`; retain the default gate for the final full suite.

## Dependencies

Internal: `../rails_helper.rb`, application Auth/Jsonapi classes, and shared factories. External dependencies vary by child suite.

<!-- MANUAL: Any manually added notes below this line are preserved on regeneration -->
