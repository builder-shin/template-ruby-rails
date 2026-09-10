<!-- Parent: ../AGENTS.md -->
<!-- Generated: 2026-09-11 | Updated: 2026-09-11 -->

# spec/lib/auth

## Purpose

Contracts for Argon2 passwords, signed JWT claims, and database-backed refresh-token issuance/rotation/logout.

## Key Files

| File | Description |
|------|-------------|
| `passwords_spec.rb` | Verifies salted Argon2id hashes, corrupted-hash failures, and the memoized dummy hash's randomness and matching cost. |
| `tokens_spec.rb` | Exercises signed claims, type/signature/issuer/audience/time checks, expired-refresh decoding, digest matching, and private helpers. |
| `refresh_sessions_spec.rb` | Checks token/session identity, rotation/replay/expiry/logout state, user-before-session lock order, concurrent rotation, and caller transaction ownership. |

## For AI Agents

### Working In This Directory

- Build malformed tokens with a valid signature and controlled payload to reach the intended claims guard.
- Keep expired JWTs and expired database rows independently controlled, and separate token-hash mismatch from user-ID mismatch.
- Wrap rotate/logout in caller-owned transactions; preserve failure-return and committed-revocation assertions.
- Keep transaction-ownership/concurrency groups outside transactional fixtures with explicit DatabaseCleaner truncation and connection cleanup.
- Preserve the documented `exp: null` decode/expired-refresh composition; changing error classification affects rotation behavior.

### Testing Requirements

Run `bundle exec rspec spec/lib/auth` from the repository root with the PostgreSQL/JWT environment in `../../AGENTS.md`. Focused runs may set `COVERAGE_MINIMUM=0`; final full runs keep the gate. Nontransactional groups truncate the test database and require independent PostgreSQL connections.

## Dependencies

Internal: `../../rails_helper.rb`, `../../factories/users.rb`, Rails auth configuration, Auth password/token/session modules, User, and RefreshSession. External: RSpec Rails, Argon2, JWT, OpenSSL, Base64, SecureRandom, PostgreSQL, DatabaseCleaner ActiveRecord, and Concurrent::CyclicBarrier.

<!-- MANUAL: Any manually added notes below this line are preserved on regeneration -->
