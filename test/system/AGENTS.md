<!-- Parent: ../AGENTS.md -->
<!-- Generated: 2026-09-11 | Updated: 2026-09-11 -->

# test/system

## Purpose

Placeholder for browser system tests; it currently contains only an empty `.keep` file.

## Key Files

| File | Description |
|------|-------------|
| `.keep` | Keeps this otherwise empty test category in version control. |

## For AI Agents

### Working In This Directory

- New browser tests should inherit `ApplicationSystemTestCase`, which configures Selenium headless Chrome.

### Testing Requirements

No executable tests exist here. For new tests use `bin/rails test:system`; Chrome and Selenium are required.

## Dependencies

Internal: `../application_system_test_case.rb` and `../test_helper.rb`. External: Rails system testing, Selenium, and Chrome.

<!-- MANUAL: Any manually added notes below this line are preserved on regeneration -->
