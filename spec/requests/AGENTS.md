<!-- Parent: ../AGENTS.md -->
<!-- Generated: 2026-09-11 | Updated: 2026-09-11 -->

# spec/requests

## Purpose

HTTP request contracts for the versioned JSON:API plus health and served documentation endpoints.

## Key Files

| File | Description |
|------|-------------|
| `health_spec.rb` | Checks DB-independent liveness, SELECT 1 readiness, safe database 503 responses, and the global safe 500 handler. |
| `api_docs_spec.rb` | Requests the committed Swagger YAML through its serving endpoint and checks its OpenAPI shape. |

## Subdirectories

| Directory | Purpose |
|-----------|---------|
| [api/](api/AGENTS.md) | Versioned resource/authentication HTTP contracts. |

## For AI Agents

### Working In This Directory

- Use `jsonapi_headers` and `parsed_body` from shared support where JSON:API applies.
- Health endpoints intentionally accept non-JSON:API Accept headers; preserve their separate liveness/readiness behavior.
- Keep tests comparing generated Swagger content with source definitions in `spec/configuration`, because rswag writes its output after request spec processing.

### Testing Requirements

Run `bundle exec rspec spec/requests` from the repository root with the environment described in `../AGENTS.md`. A focused run may set `COVERAGE_MINIMUM=0`; retain the default gate for the final full suite.

## Dependencies

Internal: `../rails_helper.rb`, `../support/`, Rails routes/controllers, and committed Swagger. External: RSpec Rails, FactoryBot, Rails integration requests, and PostgreSQL/pg.

<!-- MANUAL: Any manually added notes below this line are preserved on regeneration -->
