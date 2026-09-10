<!-- Parent: ../AGENTS.md -->
<!-- Generated: 2026-09-11 | Updated: 2026-09-11 -->

# spec/architecture

## Purpose

Repository-level checks for the sample domain, required runtime integrations, and executable README instructions.

## Key Files

| File | Description |
|------|-------------|
| `sample_domain_spec.rb` | Scans Git-tracked app/config/dependency files for removed integrations and checks required job/storage and README API/auth instructions. |

## For AI Agents

### Working In This Directory

- Keep Git-based source enumeration so generated and untracked runtime files do not accidentally expand this contract.
- When changing README setup or token behavior, update the explicit README assertions together with the documented behavior.
- Keep removed Blog, EmailTemplate, SendGrid, and Sentry references out of the tracked source set tested here.

### Testing Requirements

Run `bundle exec rspec spec/architecture` from the repository root with the environment described in `../AGENTS.md`. A focused run may set `COVERAGE_MINIMUM=0`; retain the default gate for the final full suite.

## Dependencies

Internal: `../rails_helper.rb`; the spec reads tracked app/config files, Gemfile/lock, `.env.example`, and README. External: RSpec Rails, Git, and Ruby Open3.

<!-- MANUAL: Any manually added notes below this line are preserved on regeneration -->
