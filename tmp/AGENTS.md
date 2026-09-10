<!-- Parent: ../AGENTS.md -->
<!-- Generated: 2026-09-11 | Updated: 2026-09-11 -->

# tmp

## Purpose

Temporary runtime directory with a root `.keep` placeholder and separate PID and storage directories.

## Key Files

| File | Description |
|------|-------------|
| `.keep` | Empty file preserving this directory in Git. |

## Subdirectories

| Directory | Purpose |
|-----------|---------|
| [pids/](pids/AGENTS.md) | Process ID placeholders. |
| [storage/](storage/AGENTS.md) | Temporary storage placeholder. |

## For AI Agents

### Working In This Directory

Keep temporary output out of source control. `bin/setup` invokes `bin/rails tmp:clear`; do not place durable implementation files here.

### Testing Requirements

No executable implementation exists here. Documentation and placeholder edits need path/encoding checks; changes to the producing application configuration need its relevant tests.

## Dependencies

`bin/setup`, root ignore files, and Rails runtime.

<!-- MANUAL: Any manually added notes below this line are preserved on regeneration -->
