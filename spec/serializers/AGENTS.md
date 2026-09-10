<!-- Parent: ../AGENTS.md -->
<!-- Generated: 2026-09-11 | Updated: 2026-09-11 -->

# spec/serializers

## Purpose

Example JSON:API serialization contracts, including relationship linkage and included reference resources.

## Key Files

| File | Description |
|------|-------------|
| `example_serializer_spec.rb` | Checks exact attributes/relationships, lowercase UUIDs, canonical links, optional included data, and controlled struct inputs. |

## For AI Agents

### Working In This Directory

- Preserve controlled uppercase UUID struct fixtures; database-backed UUID normalization can conceal a serializer regression.
- Assert exact attribute/relationship keys and self/related links, including the distinction between omitted `included` and an explicitly empty array.
- Keep serializer tests consistent with request-level wire-format assertions.

### Testing Requirements

Run `bundle exec rspec spec/serializers` from the repository root with the environment described in `../AGENTS.md`. A focused run may set `COVERAGE_MINIMUM=0`; retain the default gate for the final full suite.

## Dependencies

Internal: `../rails_helper.rb`, Example factories, `ExampleSerializer`, and included reference resources. External: RSpec Rails, FactoryBot, and JSON serialization.

<!-- MANUAL: Any manually added notes below this line are preserved on regeneration -->
