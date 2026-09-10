<!-- Parent: ../AGENTS.md -->
<!-- Generated: 2026-09-11 | Updated: 2026-09-11 -->

# helpers

## Purpose

View-helper scaffold containing the empty ApplicationHelper module.

## Key Files

| File | Description |
|------|-------------|
| [application_helper.rb](application_helper.rb) | Empty shared Rails view-helper module. |

## For AI Agents

Add helpers only for concrete view behavior; shared API/query/auth behavior belongs in the existing controllers/concerns and app/lib structure. There are no dedicated helper specs, and spec/rails_helper.rb excludes this scaffold file from coverage. Test new helpers through focused helper/view examples when behavior is introduced.

## Dependencies

Rails view helpers and templates under app/views; no custom helper dependencies currently exist.

<!-- MANUAL: Any manually added notes below this line are preserved on regeneration -->
