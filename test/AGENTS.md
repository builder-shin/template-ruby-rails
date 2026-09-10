<!-- Parent: ../AGENTS.md -->
<!-- Generated: 2026-09-11 | Updated: 2026-09-11 -->

# test

## Purpose

Rails Minitest and browser-test scaffolding retained alongside the active RSpec suite in `../spec/`. The only test class below this tree contains a commented-out Action Cable example; the other test categories are placeholders.

## Key Files

| File | Description |
|------|-------------|
| `test_helper.rb` | Loads Rails in test mode, enables processor-count parallelization, and loads all fixture sets. |
| `application_system_test_case.rb` | Uses Selenium headless Chrome with a 1400 by 1400 viewport. |

## Subdirectories

| Directory | Purpose |
|-----------|---------|
| [channels/](channels/AGENTS.md) | Action Cable connection test scaffold. |
| [controllers/](controllers/AGENTS.md) | Controller-test placeholder. |
| [fixtures/](fixtures/AGENTS.md) | Fixture-file container. |
| [helpers/](helpers/AGENTS.md) | Helper-test placeholder. |
| [integration/](integration/AGENTS.md) | Integration-test placeholder. |
| [mailers/](mailers/AGENTS.md) | Mailer-test placeholder. |
| [models/](models/AGENTS.md) | Model-test placeholder. |
| [system/](system/AGENTS.md) | System-test placeholder. |

## For AI Agents

### Working In This Directory

- Do not interpret `.keep` files or the commented connection example as implemented test coverage.
- New Minitest classes should require `test_helper`; browser tests should inherit `ApplicationSystemTestCase`.
- Match the test framework of the area being changed; current API and model contracts are documented under `../spec/AGENTS.md`.

### Testing Requirements

Run `bin/rails test` for Minitest additions and `bin/rails test:system` for actual system tests. Rails boot requires the test PostgreSQL settings and JWT secret documented at the repository root. System tests additionally need Chrome and the Selenium driver. Documentation-only updates do not require running these commands.

### Common Patterns

`test_helper.rb` sets `RAILS_ENV` only when unset, loads `rails/test_help`, enables parallel workers, and uses `fixtures :all`.

## Dependencies

### Internal

`test_helper.rb` loads `../config/environment`; `application_system_test_case.rb` depends on the helper. The substantive RSpec coverage is in `../spec/`.

### External

Rails Minitest/ActiveSupport test support, Action Cable, Capybara, Selenium WebDriver, Chrome, and PostgreSQL.

<!-- MANUAL: Any manually added notes below this line are preserved on regeneration -->
