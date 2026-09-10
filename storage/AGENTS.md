<!-- Parent: ../AGENTS.md -->
<!-- Generated: 2026-09-11 | Updated: 2026-09-11 -->

# storage

## Purpose

Local uploaded-file storage location retained with a `.keep` file. Generated contents are excluded by the root ignore rules.

## Key Files

| File | Description |
|------|-------------|
| `.keep` | Empty file preserving this directory in Git. |

## For AI Agents

### Working In This Directory

Change storage behavior in `config/storage.yml` and related application code. Keep uploaded content out of source control; preserve the directory placeholder.

### Testing Requirements

No executable implementation exists here. Documentation and placeholder edits need path/encoding checks; changes to the producing application configuration need its relevant tests.

## Dependencies

Active Storage configuration and the root `.gitignore`.

<!-- MANUAL: Any manually added notes below this line are preserved on regeneration -->
