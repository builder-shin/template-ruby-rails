<!-- Parent: ../AGENTS.md -->
<!-- Generated: 2026-09-11 | Updated: 2026-09-11 -->

# config

## Purpose

Rails boot, routes, environment settings, translations, and service configuration. The application is API-only with cookie/session middleware explicitly restored, Korean as the default locale, Asia/Seoul time, and Sidekiq as the default job adapter.

## Key Files

| File | Description |
|------|-------------|
| `application.rb` | Application configuration, Rails 7.2 compatibility defaults, autoload exclusions, API/session settings, and development/test rswag execution configuration. |
| `boot.rb` | Selects the Gemfile and loads Bundler and Bootsnap. |
| `environment.rb` | Loads and initializes the Rails application. |
| `routes.rb` | Mounts API documentation, health checks, versioned API endpoints, relationships, and the final `/api/*unmatched` fallback. |
| `health_check_host_authorization.rb` | Shared `/health` prefix exclusion used by development and production Host authorization. |
| `database.yml` | PostgreSQL connection settings using required `DATABASE_HOST`, shared port/pool settings, and environment-specific credentials/database names. |
| `puma.rb` | Puma thread settings, optional PID/state paths, and TCP binding on port 4000 by default. |
| `storage.yml` | Test/local disk services and private Amazon S3 storage. |
| `cable.yml` | Async development, test adapter, and Redis production Action Cable configuration. |
| `sidekiq_cron.yml` | Hourly UTC schedule for `PurgeExpiredRefreshSessionsJob` on the default queue. |
| `secrets.yml` | Production secret-key reference through `SECRET_KEY_BASE`. |
| `credentials.yml.enc` | Encrypted credentials; inspect as opaque encrypted data and do not reproduce secrets in documentation. |
| `application.yml` | Currently empty configuration placeholder. |

## Subdirectories

| Directory | Purpose |
|-----------|---------|
| [environments/](environments/AGENTS.md) | Development, production, and test overrides. |
| [initializers/](initializers/AGENTS.md) | Authentication validation, middleware, integrations, logging, and worker startup. |
| [locales/](locales/AGENTS.md) | English and Korean JSON:API error translations. |

## For AI Agents

### Working In This Directory

- Read the relevant initializer and environment override together; `config.load_defaults 7.2` does not change the Rails 8.1 dependency in the Gemfile.
- Keep category/tag routes restricted to `index` and `show`. Their controllers inherit write actions, so expanding the route verbs changes the authorization boundary.
- Preserve separate `PATCH` update and `PUT` upsert routes, explicit auth actions, `/users/me`, and the placement of the API fallback after concrete routes.
- Keep development and production on the shared health exclusion constant; environment files require it explicitly before autoloading is ready.
- Configure Puma and database connection pools together. Their current fallback maximums differ when `RAILS_MAX_THREADS` is absent: Puma uses 16 and PostgreSQL uses 5.
- Keep credentials in environment/configuration mechanisms. Do not add secret values to guides or turn encrypted credentials into plaintext.

### Testing Requirements

- Follow root setup requirements for Rails boot and the PostgreSQL test database.
- For auth/environment/scheduler changes, run the relevant files under `spec/config/` and `spec/configuration/` with `bundle exec rspec`.
- Route changes need the routing specs, corresponding request specs, and Swagger contract checks. Health changes need `spec/requests/health_spec.rb` and `spec/configuration/health_check_host_authorization_spec.rb`.
- Schedule changes need `spec/configuration/sidekiq_cron_schedule_spec.rb`; successful Sidekiq boot alone does not validate job constants or malformed cron entries.

### Common Patterns

YAML configuration uses ERB environment lookups. Ruby environment files override application settings. Public API contracts use JSON:API while health endpoints are separate operational routes.

## Dependencies

### Internal

`app/` provides routed controllers, jobs, and auth helpers; `db/` supplies PostgreSQL schemas; `spec/` checks configuration/runtime contracts; `swagger/` is served by the rswag engines.

### External

Rails, Bundler, Bootsnap, PostgreSQL/pg, Puma, Sidekiq/sidekiq-cron, Redis, Active Storage, AWS S3, rswag, and Rails I18n.

<!-- MANUAL: Any manually added notes below this line are preserved on regeneration -->
