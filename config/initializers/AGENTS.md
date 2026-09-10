<!-- Parent: ../AGENTS.md -->
<!-- Generated: 2026-09-11 | Updated: 2026-09-11 -->

# initializers

## Purpose

Rails startup configuration for authentication, JSON:API, background schedules, storage, HTTP middleware, documentation, and logging. These files run when web, worker, and Rails task processes initialize the application.

## Key Files

| File | Description |
|------|-------------|
| `auth.rb` | Validates JWT environment settings and populates `config.x.auth`, including refresh-session retention. |
| `sidekiq.rb` | Loads the YAML cron schedule during Sidekiq server startup. |
| `jsonapi.rb` | Requires `jsonapi` and calls `JSONAPI::Rails.install!`. |
| `cors.rb` | Installs Rack::Cors first, with configured origins, credential support, HTTP verbs, and exposed headers. |
| `rack_attack.rb` | Declares IP throttles, suspicious-path blocking, and a JSON:API-shaped 429 responder. |
| `lograge.rb` | Enables JSON request logging and declares custom event/options payloads. |
| `filter_parameter_logging.rb` | Adds sensitive parameter filters in production and clears them in development. |
| `rswag_api.rb` | Points the serving engine to the repository `swagger` directory. |
| `rswag_ui.rb` | Registers `/api-docs/v1/swagger.yaml` in the UI. |
| `active_storage.rb` | Sets one-hour service URLs, web image content types, and proxy routes for model URLs. |
| `aws.rb` | Disables AWS SDK peer certificate verification in development. |
| `content_security_policy.rb` | Defines CSP, including inline scripts/styles for Swagger UI and no frame ancestors. |
| `cookies_serializer.rb` | Selects JSON cookie serialization. |
| `wrap_parameters.rb` | Enables JSON parameter wrapping on Action Controller load. |
| `assets.rb` | Sets asset version `1.0` and retains commented customization examples. |
| `inflections.rb` | Commented examples; no custom inflection rules are active. |
| `mime_types.rb` | Commented MIME registration placeholder. |
| `permissions_policy.rb` | Commented HTTP permissions-policy template. |

## For AI Agents

### Working In This Directory

- Keep `JWT_SECRET_KEY` mandatory in every environment, with a minimum of 32 UTF-8 bytes and no fallback signing key. Workers also execute this initializer.
- Preserve strict `Integer()` parsing, positive access/refresh lifetimes, nonnegative leeway/retention, and rejection of explicitly blank issuer/audience. Auth configuration lives in `Rails.application.config.x.auth`.
- Keep cron loading inside Sidekiq server startup. `load_from_hash!` return values are currently discarded, so schedule validation depends on the dedicated spec.
- Check actual request behavior before claiming middleware coverage: the auth throttle currently matches `/auth`, while current auth endpoints use `/api/v1/auth`; the recruitment throttle names a path absent from current routes.
- The existing Lograge comment documents that `custom_payload` does not attach to the API controller hierarchy with this configuration. Declared payload fields are not proof that request logs contain them.
- Preserve the intentional Swagger UI CSP requirements when changing script/style policy. Review environment-specific logging/AWS settings in their actual environment.

### Testing Requirements

- Run `bundle exec rspec spec/config/auth_config_spec.rb` for auth validation changes.
- Run `bundle exec rspec spec/configuration/sidekiq_cron_schedule_spec.rb` for schedule/startup changes; it validates cron parsing and enqueueable job constants without needing Redis.
- Run `spec/requests/api_docs_spec.rb` and Swagger contract checks for rswag changes. Middleware changes should be checked with affected request specs, since declarations alone do not prove execution.
- Follow the root environment and coverage guidance when running focused specs.

### Common Patterns

Initializers configure Rails or integration gems directly, use `ActiveSupport.on_load` where needed, and guard environment-specific behavior with `Rails.env`. Commented template examples are inactive configuration.

## Dependencies

### Internal

`config/sidekiq_cron.yml`, `config/routes.rb`, `swagger/v1/swagger.yaml`, auth helpers and jobs in `app/`, and the corresponding configuration/request specs.

### External

Rails/Active Support, Sidekiq/sidekiq-cron, JSONAPI::Rails, Rack::Cors, Rack::Attack, Lograge, rswag, and AWS SDK/Active Storage.

<!-- MANUAL: Any manually added notes below this line are preserved on regeneration -->
