<!-- Parent: ../AGENTS.md -->
<!-- Generated: 2026-09-11 | Updated: 2026-09-11 -->

# plans

## Purpose

Dated implementation records for the initial Example API migration, reusable JSON:API query layer (C1), and replacement of external cookie authentication with local JWT authentication (C2). The plans contain task checklists, example code, file inventories, verification commands, and historical design rationale.

## Key Files

| File | Description |
|------|-------------|
| `2026-07-15-rails-example-api-parity.md` | Twelve-task Example migration plan covering schema/models, serializers, negotiation/errors, query parsing, CRUD/upsert, relationships, external auth, legacy cleanup, Compose, and CI. |
| `2026-09-05-jsonapi-layer-parity.md` | Five-task C1 plan for query module extraction, controller-declared resource policies, opt-in totals, offset probes, keyset cursors, and public category/tag reads; ends with recorded cross-backend differences. |
| `2026-09-05-auth-port.md` | Seven-task C2 plan for users/refresh sessions, Argon2 and JWT primitives, session rotation/reuse detection, Bearer guards, auth endpoints, external-auth removal, and expiry cleanup. |

## For AI Agents

### Working In This Directory

- Read the matching design in `../specs/` and the relevant current code/specs before reusing a plan. Checklists and expected results describe intended work at the recorded starting state; unchecked boxes do not prove work remains outstanding.
- Preserve dates, Korean rationale, task ordering, interfaces, and the distinction between historical instructions and current behavior. File lists, line numbers, example counts, branch/PR references, and `.superpowers/sdd/<workspace>/gates.sh` are historical context and may no longer apply.
- The July plan uses `session_web`/external auth, forbids standalone reference-resource routes, and names removed integrations/error codes. Current routes expose read-only categories/tags and local auth actions; use current application guides for implementation.
- C1's `skip_before_action :set_current_user` handoff belongs to the transition before C2 removed that callback. Do not restore those lines from the sample controllers.
- C2's `app/lib/auth/` correction explains the namespace decision: the plan places `Auth::*` under the `app/lib` autoload root rather than directly under `app/auth`.
- C2 Task 7 prescribes `statement_timeout`, but current `PurgeExpiredRefreshSessionsJob` deliberately uses a 2,000 ms `lock_timeout` with per-batch transactions and explanatory comments. Its Passwords example also rescues `ArgonHashFail`, while current `Auth::Passwords.verify_password` lets corrupted stored-hash errors propagate. Read the implemented behavior before copying either example.
- The plans contain shell, commit, database-reset, and container-cleanup examples. Treat them as part of their historical implementation tasks; documentation maintenance does not require executing them.
- FastAPI and NestJS paths are references to sibling implementations. Their contents are not included in these plan files, and claims of parity need direct comparison when that is the active task.

### Testing Requirements

- For plan/guide edits, verify Markdown structure, local file references, and consistency with the source actually discussed. Runtime tests are unnecessary for documentation-only changes.
- If implementing a newly authorized change described here, use current root test/Swagger/security/style instructions and relevant subsystem specs. Historical expected failures, suite counts, and branch commands are not current verification evidence.
- Preserve the C1 record's distinction between identical documents and deliberate differences, including unavailable write routes, opaque cursor strings, query encoding, and optional top-level document members; verify any present-day parity claim independently.

### Common Patterns

Plans group work by files and interfaces, then list failing examples, minimal implementation, verification, and commit steps. C1/C2 explicitly separate query work from authentication and document the transitional callback dependency.

## Dependencies

### Internal

The July plan pairs with `../specs/2026-07-15-example-api-parity-design.md`; C1 and C2 pair with `../specs/2026-09-04-contract-parity-design.md`. Current implementation lives in `app/`, `config/`, and `db/`, with executable contracts in `spec/` and generated API documentation in `swagger/`.

### External

The plans reference the FastAPI and NestJS template repositories, Rails/PostgreSQL, RSpec, rswag, RuboCop, Brakeman, Docker Compose, and Sidekiq. WireMock appears in the superseded external-auth plan.

<!-- MANUAL: Any manually added notes below this line are preserved on regeneration -->
