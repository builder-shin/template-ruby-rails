<!-- Parent: ../AGENTS.md -->
<!-- Generated: 2026-09-11 | Updated: 2026-09-11 -->

# spec/requests/api

## Purpose

Namespace container for API request specifications.

## Subdirectories

| Directory | Purpose |
|-----------|---------|
| [v1/](v1/AGENTS.md) | Example CRUD/query/relationships, authentication, reference resources, and JSON:API protocol contracts. |

## For AI Agents

### Working In This Directory

- Place version-specific HTTP behavior in its version directory.
- Shared request, auth, and route catalog helpers are loaded by `spec/rails_helper.rb`.

### Testing Requirements

Run `bundle exec rspec spec/requests/api` with the PostgreSQL/JWT setup and coverage guidance in `../../AGENTS.md`.

## Dependencies

Internal: `../../rails_helper.rb`, `../../support/`, and the API route set. External: RSpec Rails integration testing.

<!-- MANUAL: Any manually added notes below this line are preserved on regeneration -->
