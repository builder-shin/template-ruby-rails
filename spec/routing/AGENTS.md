<!-- Parent: ../AGENTS.md -->
<!-- Generated: 2026-09-11 | Updated: 2026-09-11 -->

# spec/routing

## Purpose

Route-set and path-recognition checks organized by API namespace.

## Subdirectories

| Directory | Purpose |
|-----------|---------|
| [api/](api/AGENTS.md) | Versioned API routing contracts. |

## For AI Agents

### Working In This Directory

- Use router-derived sets to detect accidental added or removed routes, and path recognition to verify controller/action mapping.
- Keep response and persistence behavior in request specs.

### Testing Requirements

Run `bundle exec rspec spec/routing` from the repository root with the environment described in `../AGENTS.md`. A focused run may set `COVERAGE_MINIMUM=0`; retain the default gate for the final full suite.

## Dependencies

Internal: `../rails_helper.rb` and the Rails route set. External: RSpec Rails routing support.

<!-- MANUAL: Any manually added notes below this line are preserved on regeneration -->
