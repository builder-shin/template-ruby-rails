<!-- Parent: ../AGENTS.md -->
<!-- Generated: 2026-09-11 | Updated: 2026-09-11 -->

# spec/errors

## Purpose

Unit-level checks for the shared JSON:API error object.

## Key Files

| File | Description |
|------|-------------|
| `json_api_error_spec.rb` | Verifies source pointer/parameter/header handling, frozen normalized source hashes, HTTP error statuses, and registered error codes. |

## For AI Agents

### Working In This Directory

- Keep `source.header` checks when changing authentication error handling.
- Cover string-keyed inputs, unknown source members, absent source, and invalid status/code values independently.
- Coordinate registered error-code changes with the request error catalog assertions.

### Testing Requirements

Run `bundle exec rspec spec/errors` from the repository root with the environment described in `../AGENTS.md`. A focused run may set `COVERAGE_MINIMUM=0`; retain the default gate for the final full suite.

## Dependencies

Internal: `../rails_helper.rb`, `JsonApiError`, and `../requests/api/v1/jsonapi_errors_spec.rb`. External: RSpec Rails.

<!-- MANUAL: Any manually added notes below this line are preserved on regeneration -->
