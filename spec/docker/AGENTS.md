<!-- Parent: ../AGENTS.md -->
<!-- Generated: 2026-09-11 | Updated: 2026-09-11 -->

# spec/docker

## Purpose

RSpec assertions for development Compose services and production Docker image declarations.

## Key Files

| File | Description |
|------|-------------|
| `compose_contract_spec.rb` | Checks service/volume sets, PostgreSQL 18, dependency gates, shared environment, readiness healthcheck, and production dependency/CMD separation. |

## For AI Agents

### Working In This Directory

- Update this contract with intentional Dockerfile or Compose changes.
- Preserve the one-shot migration service and distinct API/worker startup dependencies tested here.
- These specs inspect configuration text and YAML; use the root container checks when validating actual image builds.

### Testing Requirements

Run `bundle exec rspec spec/docker` from the repository root with the environment described in `../AGENTS.md`. A focused run may set `COVERAGE_MINIMUM=0`; retain the default gate for the final full suite. For container changes also use `docker compose config --quiet` and the production build checks in CI.

## Dependencies

Internal: `../rails_helper.rb`; the spec reads root `Dockerfile` and `docker-compose.yml`. External: RSpec Rails and Ruby YAML; Docker is needed for separate build validation.

<!-- MANUAL: Any manually added notes below this line are preserved on regeneration -->
