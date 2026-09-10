<!-- Parent: ../AGENTS.md -->
<!-- Generated: 2026-09-11 | Updated: 2026-09-11 -->

# auth

## Purpose

Local authentication implementation: Argon2 password primitives, HS256 JWT creation/validation, and persistent refresh-token issuance, rotation, reuse detection, and logout.

## Key Files

| File | Description |
|------|-------------|
| [passwords.rb](passwords.rb) | Hash/verify wrappers and a cached dummy Argon2 hash for nonexistent-account login checks. |
| [tokens.rb](tokens.rb) | JWT claim validation, distinct invalid/expired failures, refresh-token SHA-256 hashing, and constant-time comparison. |
| [refresh_sessions.rb](refresh_sessions.rb) | TokenPair/Failure values and transactional session lifecycle with user-before-session locking. |

## For AI Agents

### Working In This Directory

- Auth::RefreshSessions never opens the caller's transaction. rotate/logout require one; callers must commit returned Failure outcomes before translating them into raised API errors, because revocations may already have been written.
- Lock users before refresh_sessions everywhere. issue_for_locked_user assumes the caller already locked the persisted user and checked active status.
- Reusing a revoked refresh token during rotation revokes all still-active sessions for that user. Repeated logout preserves revoked_at and does not perform that bulk revocation. Expired signed tokens can be decoded only through the refresh-specific path to locate/revoke their session.
- Keep access/refresh type checks, exact issuer/audience verification, required claims, UUID JTI normalization, finite timestamp bounds, and private decode internals. decode_expired_refresh skips expiration only; it still checks signatures and remaining claims.
- Token issuance uses one whole-second timestamp for both JWT expiry and persisted session expiry. Store only the refresh token's SHA-256 digest in session rows.
- Keep Argon2 rather than a hash with a 72-byte password cutoff. Verification errors from corrupt stored hashes propagate; they are not ordinary wrong-password results. The login controller uses dummy_hash to perform verification even when no account exists.

### Testing Requirements

Run spec/lib/auth and affected auth/user request specs. Session tests exercise failures inside explicit transactions; request tests check the HTTP boundary and commit behavior. Keep signed-token validation and database concurrency coverage intact; follow root full-suite requirements.

### Common Patterns

Modules expose module_function APIs with explicitly private implementation methods. Claims and successful/failed session outcomes are frozen values. Rails config.x.auth supplies secrets, issuer, audience, lifetimes, and leeway.

## Dependencies

### Internal

User and RefreshSession models; Api::V1::AuthController owns transactions and document validation; JsonapiAuthentication consumes access claims.

### External

Argon2, ruby-jwt, Active Record/PostgreSQL row locks, ActiveSupport::SecurityUtils, SecureRandom, and Digest.

<!-- MANUAL: Any manually added notes below this line are preserved on regeneration -->
