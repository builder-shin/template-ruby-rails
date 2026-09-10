<!-- Parent: ../AGENTS.md -->
<!-- Generated: 2026-09-11 | Updated: 2026-09-11 -->

# log

## Purpose

Runtime log location retained in Git with a `.keep` file. Root ignore rules exclude generated log contents.

## Key Files

| File | Description |
|------|-------------|
| `.keep` | Empty file preserving this directory in Git. |

## For AI Agents

### Working In This Directory

Use application logging configuration for behavior changes. Keep runtime logs out of commits. `bin/setup` invokes `bin/rails log:clear`, so files here are not durable application source.

### Testing Requirements

No executable implementation exists here. Documentation and placeholder edits need path/encoding checks; changes to the producing application configuration need its relevant tests.

## Dependencies

`bin/setup`, root `.gitignore`, and Rails logging.

<!-- MANUAL: Any manually added notes below this line are preserved on regeneration -->
