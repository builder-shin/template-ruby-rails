<!-- Parent: ../AGENTS.md -->
<!-- Generated: 2026-09-11 | Updated: 2026-09-11 -->

# spec/routing/api

## Purpose

Namespace container for versioned API route contracts.

## Subdirectories

| Directory | Purpose |
|-----------|---------|
| [v1/](v1/AGENTS.md) | Exact Example/category/tag route sets and method/action recognition. |

## For AI Agents

### Working In This Directory

- Keep routing checks organized by API version; use request specs for response behavior.

### Testing Requirements

Run `bundle exec rspec spec/routing/api` with the root test environment; focused coverage guidance is in `../../AGENTS.md`.

## Dependencies

Internal: `../../rails_helper.rb` and Rails routes. External: RSpec Rails routing support.

<!-- MANUAL: Any manually added notes below this line are preserved on regeneration -->
