<!-- Parent: ../AGENTS.md -->
<!-- Generated: 2026-09-11 | Updated: 2026-09-11 -->

# spec/requests/api/v1

## Purpose

HTTP contracts for the v1 Example resources, public reference resources, local auth endpoints, profile, and JSON:API protocol behavior.

## Key Files

| File | Description |
|------|-------------|
| `auth_spec.rb` | Registration/login/refresh/logout documents, email normalization, validation, uniqueness races, lock waiting, and durable revocation. |
| `examples_auth_spec.rb` | Public reads, eight protected writes, active-user requirements, token failures, and negotiation/query-before-auth ordering. |
| `examples_crud_spec.rb` | Resource CRUD, embedded relationships, exact wire timestamps, error pointers, PATCH semantics, and transactional rollback. |
| `examples_upsert_spec.rb` | Atomic PUT creation/replacement, defaults, canonical UUIDs, rollback, and concurrent 200/201 outcomes. |
| `examples_query_spec.rb` | Contract-driven filters/sorts/includes, raw query collision handling, offset/keyset pagination, totals, and link traversal. |
| `examples_action_query_spec.rb` | Action-specific query allowlists and rejection before persistence changes. |
| `example_relationships_spec.rb` | Category/tag linkage mutations, canonical order, related resources, tag pagination, and rollback on failures. |
| `example_relationship_concurrency_spec.rb` | Observes parent row lock waiting and idempotent concurrent additions through real HTTP sessions. |
| `reference_resources_spec.rb` | Read-only category/tag routes, sorting/filtering, canonical links, and invalid-query behavior. |
| `users_me_spec.rb` | Authenticated profile serialization, inactive-user access, private-field exclusion, and bearer errors. |
| `jsonapi_negotiation_spec.rb` | Accept/Content-Type parsing, quoted profiles, unsupported parameters, and invalid document bodies. |
| `jsonapi_errors_spec.rb` | Localized error catalogs, pointers, safe 500 handling, Vary preservation, API fallback, and Active Storage routing. |
| `jsonapi_response_media_type_spec.rb` | Exercises all successful API routes and asserts exact response media types, including absence on 204. |

## For AI Agents

### Working In This Directory

- Use real persisted users and signed JWTs from the auth helper; when testing the credential guard, avoid stubbing away the behavior under test.
- Preserve exact Content-Type equality and read/write timestamp string comparisons. For 204 responses assert empty bodies and the relevant absent headers.
- Keep IDs, timestamps, insertion order, and names deliberately different in sorting fixtures so incorrect sorting cannot produce the same answer.
- Temporary probe controllers redraw global routes; preserve `Rails.application.reload_routes!` cleanup.
- Concurrency and transaction-ownership examples disable transactional fixtures and truncate the dedicated test database. Preserve independent Integration::Session objects, connection management, thread cleanup, and lock observations.
- Keep helper hook order in mind: truncation removes previously created auth users, so concurrent PUT setup recreates the bearer user after cleaning.
- Update `spec/support/api_route_catalog.rb` and generated Swagger when adding routes; the full-route probes assert completeness against the router.
- Assert persistent state after auth failures that revoke sessions, and after CRUD/relationship hooks or serialization fail, because response status alone does not prove commit/rollback.

### Testing Requirements

Run `bundle exec rspec spec/requests/api/v1` from the repository root using the dedicated PostgreSQL/JWT environment documented in `../../../AGENTS.md`. A focused run may use `COVERAGE_MINIMUM=0`; final full validation keeps the default 80% threshold. Concurrency specs use PostgreSQL row locks and `pg_stat_activity`; provide enough pool connections for the lock owner, request threads, and observer (the configured default pool is 5). Run the configuration Swagger contracts after regenerating API documentation.

## Dependencies

Internal: `../../../rails_helper.rb`, `../../../support/`, factories, application API/auth/JSON:API classes, routes, error translations, and Swagger artifact. External: RSpec Rails, FactoryBot, PostgreSQL/pg, DatabaseCleaner ActiveRecord, Concurrent::CyclicBarrier, Argon2/JWT through the application, URI, and YAML.

<!-- MANUAL: Any manually added notes below this line are preserved on regeneration -->
