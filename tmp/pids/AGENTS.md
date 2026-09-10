<!-- Parent: ../AGENTS.md -->
<!-- Generated: 2026-09-11 | Updated: 2026-09-11 -->

# pids

## Purpose

Reserved process-ID directory, currently containing only `.keep`. Runtime PID files are ignored.

## Key Files

| File | Description |
|------|-------------|
| `.keep` | Empty file preserving this directory in Git. |

## For AI Agents

### Working In This Directory

Keep process-specific PID values out of Git. Configure PID behavior in the process/server settings that produce these files.

### Testing Requirements

No executable implementation exists here. Documentation and placeholder edits need path/encoding checks; changes to the producing application configuration need its relevant tests.

## Dependencies

Root `.gitignore` and `.dockerignore`.

<!-- MANUAL: Any manually added notes below this line are preserved on regeneration -->
