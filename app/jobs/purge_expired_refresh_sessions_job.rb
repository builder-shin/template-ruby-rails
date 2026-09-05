# frozen_string_literal: true

# 보존 기간(`REFRESH_SESSION_RETENTION_SECONDS`)을 넘긴 만료 refresh 세션을 오래된
# 순서로 배치 삭제한다. `config/sidekiq_cron.yml`이 이 잡을 **매시 정각**으로
# 등록한다(`cron: "0 * * * * UTC"`) — 정본(FastAPI) README와 같은 주기다.
#
# **선택 조건은 `expires_at` 하나뿐이다.** `revoked_at`이나 `replaced_by_id`로 더 거르지
# 않는다 — 아직 제시 가능한(유효한) 세션은 보존 설정이 무엇이든 지워지면 안 되고,
# 회전 체인의 살아 있는 링크를 끊어서도 안 된다. 정본(FastAPI)의
# `purge_expired_refresh_sessions`와 같은 조건이다.
class PurgeExpiredRefreshSessionsJob < ApplicationJob
  queue_as :default

  # 정본은 Dramatiq의 `@dramatiq.actor(max_retries=3, min_backoff=15_000)`으로 재시도를
  # 정한다. Sidekiq에서 같은 뜻이 되는 것은 ActiveJob의 `retry_on`이 아니라 이쪽이다:
  #
  # - `retry: 3` == `max_retries=3` (최초 시도 뒤 3번 더).
  # - Sidekiq의 backoff는 `job_retry.rb:238`의 `delay = (count**4) + 15`에 jitter를
  #   더한 값이라 **최솟값이 정확히 15초**다 == `min_backoff=15_000`.
  #
  # `retry_on`을 쓰지 않는 이유는 Sidekiq 자신이 어댑터 주석
  # (`sidekiq-8.1.0/lib/active_job/queue_adapters/sidekiq_adapter.rb:22-30`)에 적어 뒀다 —
  # ActiveJob 재시도는 Sidekiq UI의 Retries 탭에 뜨지 않고, 오류 데이터를 남기지 않으며,
  # 수동 재시도도 dead 처리도 안 된다. 정리 잡이 조용히 실패한 채로 남는 것이 이
  # 태스크가 막으려는 상황이므로 관측 가능한 쪽을 고른다.
  #
  # 이 선언이 실제로 메시지에 실리는 경로: 어댑터가 `Wrapper.set(wrapped: job.class, ...)`로
  # 넣고, `sidekiq-8.1.0/lib/sidekiq/job_util.rb:49`가 `item["wrapped"].get_sidekiq_options`를
  # 기본값에 merge한다. 그래서 래퍼가 아니라 **이 클래스의** 옵션이 `msg["retry"]`가 된다.
  sidekiq_options retry: 3

  # 실제로 지운 행 수와 실행한 배치(DB 왕복) 수. **배치 수를 함께 돌려주는 것이 중요하다** —
  # 정본의 테스트가 `LIMIT` 회귀를 못 잡은 이유가 총 삭제 개수만 봤기 때문이고, 올바른
  # 구현과 "한 배치가 전부 지우는" 버그 구현은 총계가 같다. 두 세계를 가르는 관측량은
  # 배치 수다. 마지막에 "더 없다"를 확인하는 빈 배치도 그대로 센다 — SELECT는 LIMIT을
  # 채울 수 있으면 반드시 채우므로, 빈(또는 짧은) 결과라야 비로소 끝을 안다.
  Result = Struct.new(:deleted, :batches, keyword_init: true)

  # 한 배치가 지우는 최대 행 수. 정본의 `batch_size: int = 1_000` 기본 인자와 같다.
  DEFAULT_BATCH_SIZE = 1_000

  # 한 번의 실행이 돌 수 있는 배치 수 상한. 정본에는 없고 NestJS에만 있다(`MAX_BATCHES`).
  # **채택한다** — 이건 공개 계약이 아니라 운영 안전장치이고, 막아 주는 것이 바로 이
  # 태스크의 주제다. `LIMIT`이 지켜지지 않는 회귀가 생기면 배치가 진행 없이 이어질 수
  # 있고, 상한이 없으면 그 잡이 워커 슬롯을 영원히 붙잡는다. 정상 정리가 여기까지 오면
  # 그 자체가 버그의 증거이므로 경고를 남기고 멈춘다.
  MAX_BATCHES = 10_000

  # 배치 하나가 잠금을 기다릴 수 있는 상한. **`statement_timeout`이 아니라
  # `lock_timeout`이다** — 전자는 문장의 총 실행시간을 제한해서 정상적으로 오래 걸리는
  # 큰 배치까지 죽인다. 여기서 막아야 하는 것은 "오래 걸리는 것"이 아니라 "매달리는 것"이다.
  #
  # 왜 필요한가(실측): `refresh_sessions.replaced_by_id`는 `ON DELETE SET NULL`로 자기
  # 테이블을 참조한다. 이 배치가 만료 행 B를 지우면 PostgreSQL이 B를 가리키던 행 A에
  # `UPDATE ... SET replaced_by_id = NULL`을 걸어야 하고 그러려면 A를 잠가야 한다.
  # `SELECT ... FOR UPDATE SKIP LOCKED`는 **자기가 고른 행(B)**의 잠금만 피할 뿐 이
  # cascade가 요구하는 A의 잠금은 막아 주지 않는다 — 동시 회전이 A를 잡고 있으면 배치가
  # 그대로 매달린다(프로브: lock_timeout 없이 5.25초를 기다렸다. 잠금을 놓을 때까지).
  #
  # 값은 두 참조가 갈린다(정본 2,000ms / NestJS 500ms). **정본을 따른다.** 이 값이 제한하는
  # 것은 "정상적인 경합에서 기다려 줄 시간"인데, 이 저장소의 로그인 트랜잭션은 users 행을
  # 잠근 채 argon2 검증을 수행하고 그 비용만 33ms대다(Task 2 실측) — 풀 대기까지 겹치면
  # 500ms는 정상 경합과 이상 상황을 가르기에 빠듯하다. 2,000ms는 재시도 backoff 최솟값
  # 15초의 1/7.5이라 배치가 중단돼도 재시도 주기와 겹쳐 쌓이지 않는다.
  LOCK_TIMEOUT_MS = 2_000

  # `SET LOCAL`에는 파라미터 자리표시자를 쓸 수 없어 값을 SQL 문자열에 직접 이어 붙여야
  # 한다 — 그 자리가 곧 주입 표면이다. NestJS는 런타임에 정수인지 검사해서 막지만, 여기서는
  # **로드 시각에 상수 하나로 굳혀** 런타임 보간 자체를 없앤다. 나중에 이 값을 설정으로 빼려는
  # 사람은 이 상수를 문자열 조립으로 되돌려야 하고, 그 순간이 검사를 넣어야 할 자리다.
  #
  # `SET LOCAL`이어야 하는 이유: 커넥션 풀을 다른 잡과 공유하므로 이 배치의 트랜잭션 밖으로
  # 설정이 새면 안 된다. 그래서 `run_batch`의 트랜잭션 안에서만 실행한다.
  LOCK_TIMEOUT_SQL = "SET LOCAL lock_timeout = '#{LOCK_TIMEOUT_MS}ms'"

  # 배치 하나가 실행하는 실제 SQL. 구현과 스펙이 **같은 문자열**을 쓴다 — 스펙이 따로
  # 베껴 적으면 구현이 바뀔 때 조용히 어긋난다(NestJS가 `PURGE_BATCH_SQL`을 export하는 것과
  # 같은 드리프트 방지). 스펙이 이 상수를 직접, 한 번만 돌려 보는 것이 이 잡에서 배치 동작을
  # 관측할 수 있는 유일한 방법이기도 하다: `perform`은 짧은 배치를 볼 때까지 조건에 맞는
  # 행을 전부 지우므로, 호출이 끝난 뒤의 DB 상태만으로는 `ORDER BY`가 있었는지도 `LIMIT`이
  # 지켜졌는지도 구분되지 않는다.
  #
  # **후보 선택을 CTE로 감싼 것이 정본(FastAPI)과 갈리는 유일한 지점이다.** 정본은
  # `DELETE ... WHERE id IN (SELECT ... FOR UPDATE SKIP LOCKED LIMIT n)`로 서브쿼리를
  # 그대로 둔다. 그 모양은 `DELETE`의 대상 테이블과 서브쿼리의 테이블이 같아서, 플래너가
  # 부수효과를 가진 그 서브쿼리를 바깥 스캔의 행마다 다시 실행하는 계획을 고르면
  # `FOR UPDATE`가 매번 다른 행을 잠그면서 **`LIMIT`이 사실상 무시된다.**
  #
  # 실측(PostgreSQL 18.6, 이 저장소의 test DB): 기본 플래너 설정에서는 그 일이 **일어나지
  # 않는다** — 플래너가 서브쿼리를 `HashAggregate`로 유일화하거나 `Materialize`를 끼워
  # 넣어 어느 쪽이든 한 번만 계산한다. 3~50,000행 · `LIMIT` 1~1,000 · 인덱스 유무 ·
  # 통계 유무의 11개 조합에서 전부 `LIMIT`이 정확히 지켜졌다.
  #
  # **재현하려면 GUC 하나로는 안 된다 — 네 개를 함께 꺼야 하고 각각이 개별적으로
  # 필요하다.** 하나씩 되돌린 대조로 실측했다(만료 3행, `LIMIT 1`, heap=asc):
  #
  #     enable_material·hashagg·sort·hashjoin off   -> 3행 삭제 (LIMIT 위반)
  #       + enable_material 만 되돌림                -> 1행  `Materialize (loops=3)` 가 구한다
  #       + enable_hashagg  만 되돌림                -> 1행  `HashAggregate (loops=1)` 가 구한다
  #       + enable_sort     만 되돌림                -> 1행  `Unique`←`Sort` 가 구한다
  #       + enable_hashjoin 만 되돌림                -> 1행  `Hash Semi Join` 이 구한다
  #
  # 즉 네 개는 각각 "후보를 한 번만 계산하는" 서로 다른 우회로를 하나씩 막는다. 넷을
  # 다 막았을 때에만 계획이 `Nested Loop Semi Join` + `Subquery Scan on "ANY_subquery"
  # ... loops=3`으로 내려가고, 그때 만료 3행이 `LIMIT 1`로 **통째로 지워진다.**
  # (`enable_mergejoin`·`enable_memoize`는 이 스키마에서 필요 없다 — 스펙이 방어적으로
  # 함께 걸 뿐이고, 빼도 결과가 같다.)
  #
  # **그리고 heap 순서가 `expires_at` 오름차순이어야 한다.** 서브쿼리가 재실행될 때
  # 이번 DELETE가 이미 지운 행은 `TM_SelfModified`로 건너뛰어져 매번 다른 후보가
  # 뽑히지만, 그 후보가 실제로 지워지려면 바깥 Seq Scan이 heap 순서로 그 행에 나중에
  # 도달해야 한다. heap 역순이면 같은 설정에서도 1행만 지워져 **우연히 정상으로 보인다**
  # (실측). 스펙이 이 두 조건을 함께 세우는 이유이자, 그 예제가 픽스처 삽입 순서를
  # 명시적으로 단언하는 이유다.
  #
  # 즉 정본의 정확성은 오늘의 플래너 선택에 기대고 있고, 그 선택은 통계·설정·버전에
  # 따라 바뀔 수 있는 종류의 것이다.
  #
  # CTE는 그 의존을 없앤다. PostgreSQL은 `FOR UPDATE`처럼 부수효과가 있는 WITH 질의를
  # 상위 질의로 인라인하지 못하므로 반드시 한 번만 계산한다 — 위의 네 GUC를 다 끈
  # 설정에서도 `CTE candidates ... loops=1`로 정확히 1행만 지운다. 잠금·`SKIP LOCKED`
  # 의미는 그대로다.
  #
  # **`AS MATERIALIZED` 키워드 자체는 오늘 아무 동작도 바꾸지 않는다** — 실측으로 확인했다.
  # 키워드를 뗀 `WITH candidates AS (...)`도 같은 적대적 설정에서 같은 계획(`loops=1`)과
  # 같은 결과를 낸다. 위의 인라인 금지 규칙이 `FOR UPDATE` 때문에 이미 걸리기 때문이다.
  # 그래도 남겨 둔다: 보장이 "이 CTE는 부수효과가 있다"는 플래너의 추론에 딸려 오는
  # 대신 **문장 자체에 적혀 있게** 되고, NestJS와도 같은 문장이 된다. 다만 이 잡의
  # 정확성을 실제로 떠받치는 것은 키워드가 아니라 **CTE로 감쌌다는 사실**이다.
  #
  # 그래서 `spec/jobs/purge_expired_refresh_sessions_job_spec.rb`의 해당 예제는
  # 이 문장을 **플래너를 적대적으로 설정한 채** 돌린다. 기본 설정에서는 CTE 모양과 정본의
  # 서브쿼리 모양이 같은 결과를 내므로, 그렇게 하지 않으면 정본으로 되돌리는 뮤테이션이
  # 그대로 살아남는다.
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
    unless batch_size.is_a?(Integer) && batch_size.positive?
      Rails.logger.warn(
        "[PurgeExpiredRefreshSessionsJob] skipped: batch_size must be a positive integer " \
        "(got #{batch_size.inspect})"
      )
      return Result.new(deleted: 0, batches: 0)
    end

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
        ActiveRecord::Relation::QueryAttribute.new("batch_size", batch_size, ActiveRecord::Type::Integer.new)
      ]).length
    end
  end
end
