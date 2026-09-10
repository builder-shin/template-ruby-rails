<!-- Parent: ../AGENTS.md -->
<!-- Generated: 2026-09-11 | Updated: 2026-09-11 -->

# spec/lib/jsonapi

## Purpose

Cursor encoding/decoding and cursor-specific query parser contract tests.

## Key Files

| File | Description |
|------|-------------|
| `cursor_spec.rb` | Tests signature/value-count checks, early length rejection, supported value serialization, exact error parameter, string-only cursor payloads, and nullable-sort restrictions. |

## For AI Agents

### Working In This Directory

- Keep oversized-input tests proving rejection before Base64 decoding; malformed input alone would also fail after decoding.
- Use a test-only nullable contract to exercise nullable cursor rejection; do not widen public sort contracts for test convenience.
- Pass nested ActionController parameters derived from the test request to QueryParser so tests reach the intended validation layer.
- Preserve exact `page[before]` versus `page[after]` error-source assertions.

### Testing Requirements

Run `bundle exec rspec spec/lib/jsonapi` with the root PostgreSQL/JWT test environment. Focused runs may set `COVERAGE_MINIMUM=0`; use the default threshold for final full-suite validation.

## Dependencies

Internal: `../../rails_helper.rb`, Example factories, Jsonapi::Cursor, Jsonapi::QueryParser, JsonApiError, and the Example controller's query contract. External: RSpec Rails, Base64, JSON, URI, BigDecimal, Rails test requests, and PostgreSQL.

<!-- MANUAL: Any manually added notes below this line are preserved on regeneration -->
