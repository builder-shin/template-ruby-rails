<!-- Parent: ../AGENTS.md -->
<!-- Generated: 2026-09-11 | Updated: 2026-09-11 -->

# tasks

## Purpose

Reserved custom Rake-task directory, currently containing only `.keep`. Root `Rakefile` explicitly identifies `lib/tasks/*.rake` as the custom task location.

## Key Files

| File | Description |
|------|-------------|
| `.keep` | Empty file preserving this directory in Git. |

## For AI Agents

### Working In This Directory

Use `.rake` files for custom tasks. Run `bin/rake -T` to check task discovery after adding a task, and exercise changed task behavior in the appropriate configured environment.

### Testing Requirements

No executable implementation exists here. Documentation and placeholder edits need path/encoding checks; changes to the producing application configuration need its relevant tests.

## Dependencies

Root `Rakefile`, Rails task loading, and Rake.

<!-- MANUAL: Any manually added notes below this line are preserved on regeneration -->
