<!-- Parent: ../AGENTS.md -->
<!-- Generated: 2026-09-11 | Updated: 2026-09-11 -->

# test/fixtures/files

## Purpose

Placeholder for file assets used by Minitest fixtures or tests; no fixture files are present.

## Key Files

| File | Description |
|------|-------------|
| `.keep` | Keeps the fixture-files directory in version control. |

## For AI Agents

### Working In This Directory

- Add only intentional test assets and point the consuming tests at them.
- Do not count the placeholder as a fixture set or executable coverage.

### Testing Requirements

No executable tests exist in this directory. Run the test classes that consume any new fixture assets.

## Dependencies

Internal: `../../test_helper.rb` loads all YAML fixture sets from the fixture tree. External: Rails fixture/test support.

<!-- MANUAL: Any manually added notes below this line are preserved on regeneration -->
