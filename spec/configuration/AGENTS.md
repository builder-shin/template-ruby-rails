<!-- Parent: ../AGENTS.md -->
<!-- Generated: 2026-09-11 | Updated: 2026-09-11 -->

# spec/configuration

## Purpose

Contracts for runtime configuration, generated API documentation, coverage gates, cron scheduling, and development/production wiring.

## Key Files

| File | Description |
|------|-------------|
| `health_check_host_authorization_spec.rb` | Exercises the shared health-host exclusion inside real HostAuthorization middleware and checks both environment files reference it. |
| `production_dependencies_spec.rb` | Inspects Bundler dependency groups to separate Swagger serving from development/test generation. |
| `sidekiq_cron_schedule_spec.rb` | Checks the hourly UTC purge schedule, enqueueable class resolution, and the actual cron parser without Redis. |
| `simplecov_spec.rb` | Uses Ripper to verify the allowed SimpleCov start block, tracked files, threshold, and filters, with parser regression cases. |
| `swagger_contract_spec.rb` | Checks OpenAPI schemas, generated YAML equality, Git tracking, CI regeneration, and production-image checks. |
| `swagger_security_contract_spec.rb` | Uses request probes to compare runtime authentication requirements with the committed Swagger security declarations. |

## For AI Agents

### Working In This Directory

- Keep `swagger_security_contract_spec.rb` outside `spec/requests`; generation runs request specs before writing the new YAML, so this check must read the completed artifact.
- Derive route sets from the router and keep the shared probe catalog complete; assert that public and protected probes actually reach their expected outcomes.
- Keep cron validation independent of Redis. The spec resolves classes and parses cron strings without constructing Sidekiq cron jobs.
- Preserve middleware-level health tests and the Ripper regression cases; string matching alone would miss configuration behavior.

### Testing Requirements

Run `bundle exec rspec spec/configuration` from the repository root with the environment described in `../AGENTS.md`. A focused run may set `COVERAGE_MINIMUM=0`; retain the default gate for the final full suite. For OpenAPI changes, regenerate `swagger/v1/swagger.yaml` before running the generated-file contract checks.

## Dependencies

Internal: `../rails_helper.rb`, `../swagger_helper.rb`, `../support/api_route_catalog.rb`; configuration/CI files and committed Swagger are checked by the specs. External: RSpec Rails, Bundler, Ripper, YAML, Git/Open3, Sidekiq Cron, Fugit, Rack and ActionDispatch.

<!-- MANUAL: Any manually added notes below this line are preserved on regeneration -->
