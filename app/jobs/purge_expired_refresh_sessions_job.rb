# frozen_string_literal: true

# Delete sessions whose expiry predates the configured retention window. Valid
# sessions and rotation-chain links remain protected by the expiry predicate.
class PurgeExpiredRefreshSessionsJob < ApplicationJob
  queue_as :default
  sidekiq_options retry: 3

  # Counts include the final empty batch when it is needed to prove completion.
  Result = Struct.new(:deleted, :batches, keyword_init: true)
  DEFAULT_BATCH_SIZE = 1_000
  MAX_BATCH_SIZE = (2**53) - 1
  MAX_BATCHES = 10_000

  # SKIP LOCKED applies only to candidate rows. ON DELETE SET NULL can still
  # wait for a referencing session held by a concurrent token rotation. Bound
  # that wait, keep successful batches committed and propagate failures to retry.
  LOCK_TIMEOUT_MS = 2_000
  LOCK_TIMEOUT_SQL = "SET LOCAL lock_timeout = '#{LOCK_TIMEOUT_MS}ms'"

  # Materialize the candidates once: rescanning a locking DELETE subquery under
  # a nested-loop plan can delete more than LIMIT. All three backends use this
  # shape; the real PostgreSQL regression exercises the adverse planner settings.
  BATCH_SQL = <<~SQL
    WITH candidates AS MATERIALIZED (
      SELECT id FROM refresh_sessions WHERE expires_at < $1
      ORDER BY expires_at FOR UPDATE SKIP LOCKED LIMIT $2
    )
    DELETE FROM refresh_sessions WHERE id IN (SELECT id FROM candidates) RETURNING id
  SQL

  def perform(batch_size = DEFAULT_BATCH_SIZE)
    # 정본·NestJS와 같이 여기서 먼저 끊는다. `batch_size`가 0이면 `deleted < batch_size`가
    # `0 < 0`으로 영원히 거짓이라 매 배치가 아무것도 지우지 못한 채 `MAX_BATCHES`까지 빈
    # 왕복을 돌며 워커 슬롯을 붙잡는다. **이 검사가 DB를 건드리는 모든 코드보다 앞에
    # 있어야 한다** — 아래 `transaction_open?`조차 커넥션을 빌려 온다.
    valid_batch_size = batch_size.is_a?(Integer) || (batch_size.is_a?(Float) && batch_size.finite?)
    valid_batch_size &&= batch_size >= 1 && batch_size <= MAX_BATCH_SIZE && batch_size.to_i == batch_size
    unless valid_batch_size
      Rails.logger.warn(
        "[PurgeExpiredRefreshSessionsJob] skipped: batch_size must be a positive integer " \
        "(got #{batch_size.inspect})"
      )
      return Result.new(deleted: 0, batches: 0)
    end
    batch_size = batch_size.to_i

    # Task 3의 `Auth::RefreshSessions`와 정반대의 계약이다. 저쪽은 호출자가 트랜잭션을
    # 소유해야 하고, 이쪽은 **주변에 트랜잭션이 열려 있으면 안 된다.** 열려 있으면
    # `run_batch`의 `transaction`이 바깥에 합류만 해서 (a) 배치마다 커밋한다는 이 잡의
    # 존재 이유가 사라지고 — 중간 실패 시 이미 지운 행까지 롤백돼 한 행도 못 지운 것과
    # 같아진다 — (b) `SET LOCAL`이 배치가 아니라 바깥 트랜잭션에 묶여, 커넥션 풀을 공유하는
    # 다른 작업으로 timeout이 새어 나간다. 둘 다 오류도 실패하는 테스트도 없이 조용히
    # 일어나므로 여기서 시끄럽게 만든다.
    if ActiveRecord::Base.connection.transaction_open?
      raise "PurgeExpiredRefreshSessionsJob must not run inside an open transaction"
    end

    cutoff = Time.current - Rails.application.config.x.auth.refresh_session_retention_seconds
    deleted = 0
    batches = 0

    loop do
      if batches >= MAX_BATCHES
        Rails.logger.warn(
          "[PurgeExpiredRefreshSessionsJob] stopped at the batch cap " \
          "(max_batches=#{MAX_BATCHES} deleted=#{deleted})"
        )
        break
      end

      batch_deleted = run_batch(cutoff, batch_size)
      batches += 1
      deleted += batch_deleted

      # 요청한 것보다 적게 돌아왔다 = 조건에 맞는(그리고 잠기지 않은) 행이 더 없다.
      # 빈 배치(0행)도 이 조건에 걸린다.
      break if batch_deleted < batch_size
    end

    Rails.logger.info(
      "[PurgeExpiredRefreshSessionsJob] purged expired refresh sessions " \
      "(deleted=#{deleted} batches=#{batches} cutoff=#{cutoff.utc.iso8601})"
    )
    Result.new(deleted: deleted, batches: batches)
  end

  private

  # 배치 하나를 자기 트랜잭션 안에서 돌리고 커밋한다. 한 트랜잭션으로 전부 지우면 대상
  # 행 전체에 긴 잠금이 걸리고 중간 실패 시 이미 지운 행까지 롤백된다 — 배치마다 커밋하면
  # 실패해도 그 전 배치는 남고 다음 실행이 이어받는다.
  #
  # **오류를 삼키지 않는다.** 배치가 실패하면(lock_timeout의 `55P03` →
  # `ActiveRecord::LockWaitTimeout` 포함) 그대로 던져 잡이 재시도를 받게 한다. 여기서
  # 삼키면 남은 배치가 조용히 건너뛰어지고 아무도 그 사실을 모른다. 이 저장소가
  # `Auth::Passwords`에서 `Argon2::ArgonHashFail`을 삼키지 않기로 한 것과 같은 원칙이다.
  def run_batch(cutoff, batch_size)
    ActiveRecord::Base.transaction do
      connection = ActiveRecord::Base.connection
      connection.execute(LOCK_TIMEOUT_SQL)
      connection.exec_query(BATCH_SQL, self.class.name, [
        ActiveRecord::Relation::QueryAttribute.new("cutoff", cutoff, ActiveRecord::Type::DateTime.new),
        ActiveRecord::Relation::QueryAttribute.new("batch_size", batch_size, ActiveRecord::Type::Integer.new(limit: 8))
      ]).length
    end
  end
end
