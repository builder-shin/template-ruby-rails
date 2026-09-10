<!-- Parent: ../AGENTS.md -->
<!-- Generated: 2026-09-11 | Updated: 2026-09-11 -->

# spec/config

## Purpose

Focused contract tests for authentication initializer boot requirements and environment parsing.

## Key Files

| File | Description |
|------|-------------|
| `auth_config_spec.rb` | Reloads the auth initializer with controlled environment values and checks required secret, defaults, byte length, integer parsing, and blank-value rejection. |

## For AI Agents

### Working In This Directory

- Keep helper methods scoped to the example group; the source explains why top-level constants inside describe blocks can collide across files.
- Restore every touched environment value and `Rails.application.config.x.auth` in `ensure`.
- Preserve tests that distinguish strict integer parsing from `to_i`, and UTF-8 byte length from character length.

### Testing Requirements

Run `bundle exec rspec spec/config` from the repository root with the environment described in `../AGENTS.md`. A focused run may set `COVERAGE_MINIMUM=0`; retain the default gate for the final full suite.

## Dependencies

Internal: `../rails_helper.rb`; `config/initializers/auth.rb` is loaded by the spec. External: RSpec Rails and Ruby ENV.

<!-- MANUAL: Any manually added notes below this line are preserved on regeneration -->
