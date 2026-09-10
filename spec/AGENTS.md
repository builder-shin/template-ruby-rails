<!-- Parent: ../AGENTS.md -->
<!-- Generated: 2026-09-11 | Updated: 2026-09-11 -->

# spec

## Purpose

Active RSpec suite for the Example JSON:API, local authentication, PostgreSQL persistence, background cleanup, and repository configuration contracts. Shared boot and generated OpenAPI definitions live here; Minitest scaffolding is separate under `test/`.

## Key Files

| File | Description |
|------|-------------|
| `rails_helper.rb` | Starts SimpleCov before Rails, rejects production, blocks external HTTP, autoloads support, maintains the test schema, and configures transactional fixtures. |
| `swagger_helper.rb` | Defines the OpenAPI 3.0.1 paths, JSON:API schemas, Bearer security, and YAML output at swagger/v1/swagger.yaml. |

## Subdirectories

| Directory | Purpose |
|-----------|---------|
| [architecture/](architecture/AGENTS.md) | Checks tracked source integration boundaries and README contract. |
| [config/](config/AGENTS.md) | Exercises JWT initializer environment parsing. |
| [configuration/](configuration/AGENTS.md) | Checks coverage configuration, Swagger, cron, dependencies, and health host authorization. |
| [docker/](docker/AGENTS.md) | Checks Dockerfile and Compose development/production contracts. |
| [errors/](errors/AGENTS.md) | Checks JsonApiError validation and source members. |
| [factories/](factories/AGENTS.md) | FactoryBot data for Example and authentication records. |
| [jobs/](jobs/AGENTS.md) | PostgreSQL refresh-session purge batching and locking. |
| [lib/](lib/AGENTS.md) | Auth and JSON:API library contracts. |
| [migrations/](migrations/AGENTS.md) | Migration replay and database schema assertions. |
| [models/](models/AGENTS.md) | Validation, associations, ordering, and database enforcement. |
| [requests/](requests/AGENTS.md) | HTTP API behavior and health/documentation endpoints. |
| [routing/](routing/AGENTS.md) | Versioned route set and recognition assertions. |
| [serializers/](serializers/AGENTS.md) | Example resource, linkage, normalization, and included serialization. |
| [support/](support/AGENTS.md) | Automatically loaded helpers and matcher/factory integration. |

## For AI Agents

### Working In This Directory

- Require `rails_helper` in specs; use `swagger_helper` when reading the OpenAPI configuration. Support files must not end in `_spec.rb`, because `rails_helper.rb` loads them separately.
- Retain the 80% default SimpleCov gate and the three explicit generated-base filters. `spec/configuration/simplecov_spec.rb` validates the configuration structurally.
- Respect local `use_transactional_tests = false` groups and their DatabaseCleaner truncation. They measure actual commits and independent PostgreSQL connections.
- When routes change, update the successful probes in `support/api_route_catalog.rb`, OpenAPI definitions, and request/routing contracts together.
- Keep generated-file Swagger assertions in `configuration/`: rswag writes its output after processing request specs.

### Testing Requirements

From the repository root, configure a dedicated PostgreSQL test database and `JWT_SECRET_KEY` (at least 32 bytes), prepare it with `bin/rails db:create db:schema:load` under `RAILS_ENV=test`, then run `bundle exec rspec`. CI uses Ruby 3.4.8 and PostgreSQL 18. For focused development use `bundle exec rspec spec/<path>` with `COVERAGE_MINIMUM=0` set in the shell if needed; final full-suite validation keeps the default 80% gate. Regenerate Swagger with `bundle exec rails rswag:specs:swaggerize` and `COVERAGE_MINIMUM=0`, then review `swagger/v1/swagger.yaml`. AGENTS-only changes need hierarchy/link/UTF-8 checks, not application execution.

### Common Patterns

Specs commonly combine HTTP status, exact JSON:API media type, error source, and persisted-state assertions. Ordering fixtures deliberately separate UUID, insertion, name, and timestamp order. WebMock blocks non-local HTTP.

## Dependencies

### Internal

`../.github/workflows/ci.yml` defines the checks; `../config/database.yml` reads `DATABASE_HOST`, `DATABASE_PORT`, and `TEST_DATABASE_*`. Specs exercise application classes and migrations. `../test/` is separate Rails scaffolding.

### External

RSpec Rails, FactoryBot, Shoulda Matchers, SimpleCov, WebMock, DatabaseCleaner ActiveRecord, PostgreSQL/pg, rswag, and authentication gems from Gemfile.

<!-- MANUAL: Any manually added notes below this line are preserved on regeneration -->
