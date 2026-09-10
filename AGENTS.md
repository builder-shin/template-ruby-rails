<!-- Generated: 2026-09-11 | Updated: 2026-09-11 -->

# template-ruby-rails

## Purpose

Ruby 3.4.8 / Rails 8.1.2 JSON:API backend template with an Example domain, local JWT authentication, PostgreSQL persistence, and Sidekiq jobs. The current routes include Example CRUD and relationships, public read-only categories and tags, registration/login/refresh/logout, and the authenticated user's profile. Docker Compose supplies the development database, Redis, migration runner, API, and worker.

## Key Files

| File | Description |
|------|-------------|
| `README.md` | Korean setup, authentication, API usage, and validation instructions; some reference-resource descriptions predate the current routes. |
| `Gemfile` | Rails, JSON:API, authentication, storage, background job, and development/test dependencies. |
| `Gemfile.lock` | Resolved gem versions and Linux/macOS platforms; Bundler 4.0.5. |
| `.ruby-version` | Pins Ruby to 3.4.8. |
| `.env.example` | Environment template for database, Rails, JWT, Redis, storage, hosts, and CORS settings. |
| `Dockerfile` | Separate development and production stages; asset precompilation uses build-only boot variables. |
| `docker-compose.yml` | PostgreSQL 18, Redis 7, one-shot migration, Puma API on port 4000, and Sidekiq worker services. |
| `config.ru` | Rack entry point loading the Rails environment. |
| `Rakefile` | Loads Rails tasks, including custom tasks placed in `lib/tasks`. |
| `.rubocop.yml` | Inherits the Rails Omakase style rules. |
| `.gitignore` | Excludes local environment, keys, runtime output, dependencies, and coverage. |
| `.dockerignore` | Filters secrets, local artifacts, and development metadata from image build context. |
| `.gitattributes` | Marks schema/vendor files and configures encrypted-credentials diffs. |

## Subdirectories

| Directory | Purpose |
|-----------|---------|
| [.github/](.github/AGENTS.md) | CI checks for tests, Swagger freshness, style, security, and production containers. |
| [app/](app/AGENTS.md) | Controllers, reusable API/auth logic, models, serializers, jobs, and Rails presentation scaffolding. |
| [bin/](bin/AGENTS.md) | Rails, Rake, setup, lint/security launchers, and an optional shell entrypoint. |
| [config/](config/AGENTS.md) | Routes, boot, environments, initializers, translations, and service configuration. |
| [db/](db/AGENTS.md) | Migrations, generated schema, and seeds. |
| [docs/](docs/AGENTS.md) | Dated architecture designs and implementation plans. |
| [lib/](lib/AGENTS.md) | Placeholder directories for shared assets and custom Rake tasks. |
| [log/](log/AGENTS.md) | Runtime log directory placeholder. |
| [public/](public/AGENTS.md) | Static error pages, icons, and robots policy. |
| [spec/](spec/AGENTS.md) | Active RSpec suite, factories, helpers, and API/architecture/configuration contracts. |
| [storage/](storage/AGENTS.md) | Local Active Storage data directory placeholder. |
| [swagger/](swagger/AGENTS.md) | Committed generated OpenAPI document served by rswag. |
| [test/](test/AGENTS.md) | Rails Minitest and system-test scaffolding. |
| [tmp/](tmp/AGENTS.md) | Temporary runtime, PID, and test-storage placeholders. |
| [vendor/](vendor/AGENTS.md) | Vendored-file placeholder; installed bundles are ignored. |

## For AI Agents

### Working In This Directory

- Follow the closest directory guide as well as this root guide. Preserve content below each guide's manual-notes marker when refreshing documentation, and write Markdown as UTF-8.
- For implemented API behavior, inspect `config/routes.rb`, application code, and request/contract specs. The July plans describe the former external-auth design; September plans describe the local JWT and query-contract changes. The README's relationship-only category/tag description is older than the read-only routes now present.
- Keep `Gemfile` and `Gemfile.lock` consistent when changing dependencies. The lockfile currently lists Linux/macOS platforms, so do not assume it describes an installed native Windows bundle.
- Start the documented development stack with `docker compose up --build`, or configure `.env` from `.env.example` before local Rails commands. Boot requires `DATABASE_HOST` and a JWT secret of at least 32 UTF-8 bytes, including worker and database-task processes.
- When adding a required boot variable, account for CI, Compose, and the Dockerfile's asset-precompilation stage. Build-only dummy credentials must not become production defaults.
- Preserve the existing Korean explanatory prose when editing surrounding documentation or comments. Keep examples consistent with current routes, serializers, and generated OpenAPI.

### Testing Requirements

- Runtime changes: prepare a PostgreSQL test database using the `RAILS_ENV=test`, `DATABASE_HOST`, `DATABASE_PORT`, `TEST_DATABASE_*`, and `JWT_SECRET_KEY` settings illustrated in `.github/workflows/ci.yml`, then run `bundle exec rspec`.
- The full RSpec suite enforces 80% line coverage. Set `COVERAGE_MINIMUM=0` only for focused development runs or Swagger generation; retain the default gate for the final full suite.
- Run `bundle exec rubocop` and `bundle exec brakeman --no-pager -q` for relevant Ruby changes.
- API contract changes: run `bundle exec rails rswag:specs:swaggerize` with `COVERAGE_MINIMUM=0`, review the generated `swagger/v1/swagger.yaml`, and ensure regeneration leaves it unchanged once committed. CI checks this with `git diff --exit-code -- swagger/v1/swagger.yaml`.
- Container changes: run `docker compose config --quiet` and the development/production image builds described in the README. CI also checks that production contains Swagger and excludes RSpec/rswag-specs.
- For AGENTS-only edits, validate directory coverage, relative links, parent tags, timestamps, and UTF-8 encoding; application test execution is unnecessary.

### Common Patterns

- Public JSON:API uses camelCase keys and `application/vnd.api+json`; Rails internals use snake_case.
- Example reads are public and writes require a Bearer access token. Category/tag routes are restricted to index/show. Auth endpoints issue/rotate/revoke tokens, and `/api/v1/users/me` returns the authenticated profile.
- `PATCH /api/v1/examples/:id` updates, while `PUT` routes to upsert; check their separate request contracts before changing behavior.
- CI treats the generated OpenAPI document and production dependency separation as checked artifacts.

## Dependencies

### Internal

The request flow connects routes and initializers in `config/` to controllers and helpers in `app/`, persisted schemas in `db/`, and contracts under `spec/` and `swagger/`. Dated plans in `docs/` explain prior decisions but must be checked against current implementation.

### External

- Ruby 3.4.8, Rails 8.1.2, Bundler 4.0.5, and Puma.
- PostgreSQL (`pg`), Redis, Sidekiq, and sidekiq-cron.
- `jsonapi.rb`, `jsonapi-serializer`, rswag, `jwt`, and `argon2`.
- Active Storage, `image_processing`/libvips, and AWS S3 support.
- RSpec, FactoryBot, Shoulda Matchers, WebMock, SimpleCov, RuboCop, and Brakeman.

<!-- MANUAL: Any manually added notes below this line are preserved on regeneration -->
