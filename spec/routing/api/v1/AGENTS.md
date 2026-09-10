<!-- Parent: ../AGENTS.md -->
<!-- Generated: 2026-09-11 | Updated: 2026-09-11 -->

# spec/routing/api/v1

## Purpose

Exact v1 route sets and controller/action mappings for Example CRUD, upsert, linkage, related resources, and read-only categories/tags.

## Key Files

| File | Description |
|------|-------------|
| `examples_routing_spec.rb` | Checks fourteen Example method/path/action entries, recognition, absent new/edit actions, and unsupported relationship fallback. |
| `reference_resources_routing_spec.rb` | Checks exactly index/show GET routes for category and tag controllers. |

## For AI Agents

### Working In This Directory

- Keep route-set equality assertions alongside individual recognition checks; either alone misses part of the route contract.
- `/api/v1/examples/new` is recognized as `show` with ID `new`, while edit and unknown relationship paths reach the application fallback.
- Coordinate route changes with request specs and the shared successful-route probe catalog.

### Testing Requirements

Run `bundle exec rspec spec/routing/api/v1` from the repository root using the PostgreSQL/JWT environment and coverage guidance in `../../../AGENTS.md`.

## Dependencies

Internal: `../../../rails_helper.rb` and Rails route definitions. External: RSpec Rails routing support.

<!-- MANUAL: Any manually added notes below this line are preserved on regeneration -->
