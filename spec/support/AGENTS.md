<!-- Parent: ../AGENTS.md -->
<!-- Generated: 2026-09-11 | Updated: 2026-09-11 -->

# spec/support

## Purpose

Automatically loaded RSpec helpers for request documents, real bearer credentials, successful route probes, factories, and matchers.

## Key Files

| File | Description |
|------|-------------|
| `api_route_catalog.rb` | Builds successful probes for all API routes, derives router keys, and translates parameter paths to OpenAPI paths. |
| `auth_helper.rb` | Creates persisted users and real signed access tokens, with helpers for inactive users and Authorization headers. |
| `factory_bot.rb` | Includes FactoryBot syntax in RSpec groups. |
| `jsonapi_request_helper.rb` | Defines exact JSON:API headers with default Korean language and response JSON parsing. |
| `shoulda_matchers.rb` | Integrates Shoulda Matchers with RSpec and Rails. |

## For AI Agents

### Working In This Directory

- `rails_helper.rb` requires every Ruby file here in sorted order; avoid `_spec.rb` suffixes and unnecessary boot-time side effects.
- `mock_bearer_user` creates real database state and a JWT. Call it before `auth_bearer_headers` unless passing an explicit token.
- Update route probes for every `/api/v1` route change; media-type and Swagger-security specs compare their keys with the actual router.
- Give mutating probes independent records and refresh/logout probes independent tokens to avoid order-dependent failures.

### Testing Requirements

Run affected request specs and `bundle exec rspec spec/configuration/swagger_security_contract_spec.rb` after changing the route catalog. Shared-helper changes warrant the full RSpec suite using the environment described in `../AGENTS.md`.

## Dependencies

Internal: `../rails_helper.rb`, factories, Auth token/session/password helpers, the Rails router, and request/configuration consumers. External: RSpec Rails, FactoryBot, Shoulda Matchers, and JSON.

<!-- MANUAL: Any manually added notes below this line are preserved on regeneration -->
