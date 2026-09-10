<!-- Parent: ../AGENTS.md -->
<!-- Generated: 2026-09-11 | Updated: 2026-09-11 -->

# jobs

## Purpose

Active Job classes executed with the configured Sidekiq adapter. Jobs generate Active Storage image variants and remove refresh sessions after their expiration-retention window.

## Key Files

| File | Description |
|------|-------------|
| [application_job.rb](application_job.rb) | ActiveJob base; sample retry/discard policies remain commented. |
| [process_image_variants_job.rb](process_image_variants_job.rb) | Creates 80, 200, and 400 pixel square variants for supported image blobs, logging individual failures. |
| [purge_expired_refresh_sessions_job.rb](purge_expired_refresh_sessions_job.rb) | Deletes old expired sessions in bounded PostgreSQL batches, with local lock timeout, retry policy, and deletion/batch counts. |

## For AI Agents

### Working In This Directory

- PurgeExpiredRefreshSessionsJob must start outside an open transaction. Each batch commits separately, and SET LOCAL lock_timeout must remain scoped to that batch.
- Preserve the materialized candidate CTE with FOR UPDATE SKIP LOCKED, expiration-only selection, bind parameters, positive batch-size guard, and batch cap. The CTE prevents repeated candidate selection from defeating LIMIT under alternate query plans.
- Purge errors propagate to Sidekiq's three retries; do not silently swallow lock timeout or database failures. Image variant failures intentionally log and continue with remaining variants.
- The cleanup schedule is hourly at minute zero UTC in config/sidekiq_cron.yml. Coordinate schedule/class/queue changes with that configuration.

### Testing Requirements

Run spec/jobs/purge_expired_refresh_sessions_job_spec.rb and the schedule configuration spec for cleanup changes. Cleanup tests deliberately disable transactional fixtures and clean committed data so lock behavior, per-batch commits, and hostile-planner cases can be observed. The current inventory contains no dedicated image-variant job spec.

### Common Patterns

Both jobs use the default queue. Cleanup returns a Result with deleted and batches, including a final empty probe batch when one occurs. Image work resolves a blob ID and exits safely for missing or unsupported blobs.

## Dependencies

### Internal

Rails config.x.auth.refresh_session_retention_seconds, RefreshSession data, config/sidekiq_cron.yml, and the Sidekiq adapter configured in config/application.rb.

### External

Active Job, Sidekiq, Active Storage/image_processing, and PostgreSQL row locks/CTEs.

<!-- MANUAL: Any manually added notes below this line are preserved on regeneration -->
