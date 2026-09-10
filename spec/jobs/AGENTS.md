<!-- Parent: ../AGENTS.md -->
<!-- Generated: 2026-09-11 | Updated: 2026-09-11 -->

# spec/jobs

## Purpose

Behavioral PostgreSQL tests for expired refresh-session purge batching, lock handling, retention, and Sidekiq retry wiring.

## Key Files

| File | Description |
|------|-------------|
| `purge_expired_refresh_sessions_job_spec.rb` | Runs the production batch SQL and the job, verifies CTE/ordering/LIMIT behavior, SKIP LOCKED, cascade lock timeouts, committed batches, and retry options. |

## For AI Agents

### Working In This Directory

- Keep transactional fixtures disabled for the whole file and preserve truncation before/after examples; the job rejects ambient caller transactions.
- Keep heap-order fixtures deliberately different across ordering and CTE tests. The paired hostile-planner examples require ascending heap order to distinguish the subquery failure.
- The planner comparison records observed PostgreSQL 18.6 behavior. If another PostgreSQL version changes the result, investigate plans and fixture preconditions before updating the assertion.
- Keep independent checked-out connections, bounded thread joins, lock timeouts, connection release, and SQL notification cleanup.
- Check both deletion counts and batch counts; a correct total alone does not prove LIMIT or early termination.

### Testing Requirements

Run `bundle exec rspec spec/jobs` from the repository root with the environment described in `../AGENTS.md`. A focused run may set `COVERAGE_MINIMUM=0`; retain the default gate for the final full suite. Use a dedicated PostgreSQL database: these examples commit rows and truncate tables. Sidekiq message normalization is exercised without Redis.

## Dependencies

Internal: `../rails_helper.rb`, auth factories, `PurgeExpiredRefreshSessionsJob::BATCH_SQL`, `RefreshSession`, and Rails auth retention config. External: PostgreSQL/pg, RSpec Rails, DatabaseCleaner ActiveRecord, ActiveJob, and Sidekiq.

<!-- MANUAL: Any manually added notes below this line are preserved on regeneration -->
