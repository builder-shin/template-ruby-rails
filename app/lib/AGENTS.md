<!-- Parent: ../AGENTS.md -->
<!-- Generated: 2026-09-11 | Updated: 2026-09-11 -->

# lib

## Purpose

Reusable application logic separated from HTTP controller callbacks: local authentication primitives/session lifecycle and JSON:API query parsing/pagination.

## Subdirectories

| Directory | Purpose |
|-----------|---------|
| [auth/](auth/AGENTS.md) | Password hashing, JWTs, and persistent refresh-session lifecycle. |
| [jsonapi/](jsonapi/AGENTS.md) | Raw query validation, contract-driven filters/sorts, and offset/keyset pagination. |

## For AI Agents

Keep Rails callback integration in controller concerns and reusable logic here. Auth::RefreshSessions has explicit transaction/locking requirements; Jsonapi::QueryParser accepts a controller-declared contract instead of deriving SQL identifiers from request input.

## Testing Requirements

Run the relevant spec/lib tests and the API request specs exercising each caller. Follow the root guide for targeted-run coverage settings and final full-suite validation.

## Dependencies

Auth code uses Rails config.x.auth, User, and RefreshSession. Query code uses Active Record/Arel, request query strings, JsonApiError, and policy declarations in API controllers. External gems are JWT and Argon2 in addition to Rails; encoding/parsing uses Ruby standard libraries.

<!-- MANUAL: Any manually added notes below this line are preserved on regeneration -->
