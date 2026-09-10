<!-- Parent: ../AGENTS.md -->
<!-- Generated: 2026-09-11 | Updated: 2026-09-11 -->

# workflows

## Purpose

GitHub Actions CI configuration for tests, generated API documentation, Ruby checks, and production container contracts.

## Key Files

| File | Description |
|------|-------------|
| `ci.yml` | Three independent jobs: `test`, `lint`, and `container`. |

## For AI Agents

### Working In This Directory

- Retain the PostgreSQL 18 service and explicit test database settings for RSpec.
- The test-only JWT key is explicitly injected because every Rails process requires a sufficiently long key. It is not a production configuration source.
- RSpec runs before Swagger generation. Only generation receives `COVERAGE_MINIMUM=0`; do not disable the full test coverage gate.
- Keep the generated Swagger diff check and production bundle checks. The image must include `swagger/v1/swagger.yaml` and exclude `rswag-specs`, `rspec-core`, and `rspec-support`.
- The workflow uses `ruby/setup-ruby@v1` with Bundler cache and the repository Ruby pin.

### Testing Requirements

Validate YAML changes and reproduce the affected job commands in its configured environment: `bin/rails db:create db:schema:load`, `bundle exec rspec`, Swagger regeneration/diff, `bundle exec brakeman --no-pager -q`, `bundle exec rubocop -f github`, or Compose validation and production build.

### Common Patterns

Ubuntu runners, `actions/checkout@v4`, independent test/lint/container jobs, and a health-checked database service.

## Dependencies

### Internal

`.ruby-version`, `Gemfile.lock`, `config/database.yml`, `config/initializers/auth.rb`, `spec/`, `swagger/v1/swagger.yaml`, `Dockerfile`, and `docker-compose.yml`.

### External

GitHub Actions, Ruby/Bundler, PostgreSQL, and Docker Compose.

<!-- MANUAL: Any manually added notes below this line are preserved on regeneration -->
