<!-- Parent: ../AGENTS.md -->
<!-- Generated: 2026-09-11 | Updated: 2026-09-11 -->

# environments

## Purpose

Environment-specific Rails configuration overriding `config/application.rb`. Development enables reloading and debug facilities, production assumes a TLS-terminating proxy, and test configures isolated storage, mail delivery, and error handling.

## Key Files

| File | Description |
|------|-------------|
| `development.rb` | Reloading, optional local caching, configurable storage/job adapter, local mail URLs, and allowed hosts with shared health exclusions. |
| `production.rb` | Eager loading, S3 storage default, proxy/SSL policy, stdout logging, locale fallbacks, and host authorization. |
| `test.rb` | CI-dependent eager loading, null cache, temporary disk storage, test mail delivery, and rescuable exception rendering. |

## For AI Agents

### Working In This Directory

- Both development and production must explicitly require `../health_check_host_authorization` and reference `HealthCheckHostAuthorization::EXCLUDE`.
- Preserve blank `ALLOWED_HOSTS` handling with `.presence`; an empty string must retain the default host list rather than producing an empty list that disables Host checking. Development defaults to `localhost:PORT`; production defaults to `localhost`.
- Production `RAILS_FORCE_SSL` disables enforcement only for trimmed, case-insensitive `false` or `0`; other values retain it. `assume_ssl = true` is configured for proxy termination, so changes must consider its interaction with redirects and HSTS.
- Development storage/job overrides use `ACTIVE_STORAGE_SERVICE` and `ACTIVE_JOB_QUEUE_ADAPTER`; production storage defaults to `amazon`, while test always uses `:test`.
- Keep test mail delivery and temporary storage separate from real delivery/storage services. Production intentionally disables schema dumping after migrations.

### Testing Requirements

- Run `bundle exec rspec spec/configuration/health_check_host_authorization_spec.rb spec/requests/health_spec.rb` for health/host changes, using root test setup instructions.
- Exercise the affected environment's boot when changing environment-specific settings; the test environment alone cannot demonstrate production SSL, storage, or logging configuration.
- Use the documented Compose/image checks for changes affecting container readiness or proxy behavior.

### Common Patterns

Each file uses `Rails.application.configure`. Environment lookups distinguish absent values from explicitly blank values where security behavior depends on that distinction.

## Dependencies

### Internal

`config/application.rb`, the shared health authorization module, `config/storage.yml`, and health routes/request specs.

### External

Rails/Active Support, Active Storage, Sidekiq, AWS S3 for production storage, and Web Console in development.

<!-- MANUAL: Any manually added notes below this line are preserved on regeneration -->
