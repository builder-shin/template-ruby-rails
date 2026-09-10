<!-- Parent: ../AGENTS.md -->
<!-- Generated: 2026-09-11 | Updated: 2026-09-11 -->

# bin

## Purpose

Small launchers for Rails, Rake, setup, and static analysis, plus an optional Bash container entrypoint.

## Key Files

| File | Description |
|------|-------------|
| `rails` | Loads application boot and Rails commands. |
| `rake` | Loads application boot and executes Rake. |
| `setup` | Installs/checks Bundler dependencies, prepares the database, clears logs/temp files, and restarts Rails. |
| `rubocop` | Runs RuboCop with the root configuration explicitly selected. |
| `brakeman` | Runs Brakeman with `--ensure-latest` added. |
| `docker-entrypoint` | Optionally enables jemalloc, prepares DB only for the exact `./bin/rails server` invocation, then execs its arguments. |

## For AI Agents

### Working In This Directory

- Keep launchers small and retain their shebangs. Use LF line endings for scripts executed inside Linux containers.
- `setup` has database, cleanup, and restart side effects; inspect its steps before using it as a verification command.
- The current Dockerfile uses Puma directly and does not declare `docker-entrypoint` as its entrypoint. Compose owns migration through its separate `migrate` service.
- The root/CI Brakeman command does not include the launcher's `--ensure-latest` option; distinguish these invocation paths.

### Testing Requirements

Check edited Ruby launchers with `ruby -c bin/<name>`, and the Bash entrypoint with `bash -n bin/docker-entrypoint`. Exercise changed boot behavior in a configured development/test environment; use the container checks from the root guide for entrypoint wiring.

### Common Patterns

Ruby launchers resolve paths relative to `__dir__` and load Bundler or `config/boot.rb`. The shell script uses `exec` to forward the container process.

## Dependencies

### Internal

`config/boot.rb`, `config/application.rb`, `Rakefile`, `.rubocop.yml`, `Dockerfile`, and `docker-compose.yml`.

### External

Ruby, Bundler, Rails, Rake, RuboCop, Brakeman; Bash for the shell entrypoint.

<!-- MANUAL: Any manually added notes below this line are preserved on regeneration -->
