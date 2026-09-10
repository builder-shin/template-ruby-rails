<!-- Parent: ../AGENTS.md -->
<!-- Generated: 2026-09-11 | Updated: 2026-09-11 -->

# spec/factories

## Purpose

FactoryBot fixtures for Example categories/tags/taggings and authentication users/refresh sessions.

## Key Files

| File | Description |
|------|-------------|
| `examples.rb` | Sequential Example/reference-resource factories with explicit with_category and with_tags traits. |
| `users.rb` | User factory with a reused Argon2 hash and refresh-session factory with an explicit UUID and optional revocation/replacement fields. |

## For AI Agents

### Working In This Directory

- Keep Example relationships opt-in via traits; the base factory intentionally has no category or tags.
- `DEFAULT_USER_PASSWORD_HASH` hashes `password` once at load time. HTTP login inputs require at least 12 characters, so override `password_hash` for login scenarios.
- Always supply refresh-session IDs: these represent refresh JWT jti values and the database intentionally has no ID default.
- Use explicit deterministic IDs/timestamps in sorting tests when insertion order must differ from the asserted order.

### Testing Requirements

Run `bundle exec rspec spec/models` and the affected request/library specs after changing factory defaults. The full suite is appropriate for shared factory changes; use the environment and coverage guidance in `../AGENTS.md`.

## Dependencies

Internal: `../rails_helper.rb`, `../support/factory_bot.rb`, Example domain/auth model classes, and `Auth::Passwords`. External: FactoryBot, SecureRandom, Rails time helpers, and Argon2 through the password helper.

<!-- MANUAL: Any manually added notes below this line are preserved on regeneration -->
