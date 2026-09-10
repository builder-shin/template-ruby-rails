<!-- Parent: ../AGENTS.md -->
<!-- Generated: 2026-09-11 | Updated: 2026-09-11 -->

# storage

## Purpose

Temporary storage directory, currently containing only `.keep`. Generated storage contents are ignored.

## Key Files

| File | Description |
|------|-------------|
| `.keep` | Empty file preserving this directory in Git. |

## For AI Agents

### Working In This Directory

Keep fixture definitions in the test suites and runtime file output here. Preserve the placeholder without committing temporary uploads.

### Testing Requirements

No executable implementation exists here. Documentation and placeholder edits need path/encoding checks; changes to the producing application configuration need its relevant tests.

## Dependencies

Root `.gitignore` and `.dockerignore`; Rails storage configuration.

<!-- MANUAL: Any manually added notes below this line are preserved on regeneration -->
