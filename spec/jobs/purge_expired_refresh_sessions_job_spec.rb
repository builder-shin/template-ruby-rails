# frozen_string_literal: true

require "rails_helper"
require "database_cleaner/active_record"

# **이 파일 전체가 `use_transactional_tests = false` 다.** 이 잡의 핵심 세 가지 —
# 배치마다 커밋한다는 것, `SET LOCAL` 이 배치의 트랜잭션에만 묶인다는 것, 그리고
# 동시 잠금(`SKIP LOCKED`·`lock_timeout`)이 실제로 동작한다는 것 — 은 주변에 RSpec 이
# 열어 둔 트랜잭션이 있으면 하나도 관측되지 않는다. 게다가 `perform` 은 주변
# 트랜잭션이 열려 있으면 스스로 raise 하므로, 기본 픽스처 아래에서는 애초에 돌지도
# 않는다(그 계약 자체를 검사하는 예제가 아래에 있다).
#
# 대가는 데이터가 실제로 커밋된다는 것이다 — `DatabaseCleaner` 로 예제 전후를 모두
# 정리한다. `spec/requests/api/v1/example_relationship_concurrency_spec.rb` 와
# `spec/requests/api/v1/auth_spec.rb` 의 선례와 같은 모양이다.
RSpec.describe PurgeExpiredRefreshSessionsJob do
  self.use_transactional_tests = false

  before do
    ActiveRecord::Base.connection_handler.clear_active_connections!
    DatabaseCleaner.clean_with(:truncation)
  end

  after do
    @threads&.each { |thread| thread.join(5) }
    ActiveRecord::Base.connection_handler.clear_active_connections!
    DatabaseCleaner.clean_with(:truncation)
    ActiveRecord::Base.connection_handler.clear_active_connections!
  end

  let(:retention_seconds) { Rails.application.config.x.auth.refresh_session_retention_seconds }
  let(:user) { create(:user) }

  # 보존 기간을 `seconds_past` 만큼 더 지난 만료 세션.
  def purgeable(seconds_past, **attributes)
    create(:refresh_session, user: user, expires_at: retention_seconds.seconds.ago - seconds_past, **attributes)
  end

  def session_ids
    RefreshSession.order(:expires_at).pluck(:id)
  end

  # 구현이 쓰는 것과 **같은 문자열**(`described_class::BATCH_SQL`)을 한 번만 돌린다.
  # 스펙이 SQL 을 따로 베껴 적으면 구현이 바뀔 때 조용히 어긋난다.
  #
  # `perform` 을 통째로 부르면 배치 동작은 아무것도 관측되지 않는다 — 조건에 맞는
  # 행을 짧은 배치를 볼 때까지 전부 지우므로, 호출이 끝난 뒤의 DB 상태로는 `ORDER BY`
  # 가 있었는지도 `LIMIT` 이 지켜졌는지도 구분할 수 없다. 그래서 한 문장을 직접 돌린다.
  def run_batch_sql(limit, cutoff: Time.current, session_sql: [])
    ActiveRecord::Base.transaction do
      connection = ActiveRecord::Base.connection
      Array(session_sql).each { |statement| connection.execute(statement) }
      connection.exec_query(described_class::BATCH_SQL, "spec batch", [
        ActiveRecord::Relation::QueryAttribute.new("cutoff", cutoff, ActiveRecord::Type::DateTime.new),
        ActiveRecord::Relation::QueryAttribute.new("batch_size", limit, ActiveRecord::Type::Integer.new)
      ]).to_a.map { |row| row["id"] }
    end
  end

  # 다른 커넥션(다른 PostgreSQL 백엔드)에서 행 하나를 잠근 채로 블록을 실행한다.
  # `SKIP LOCKED` 와 cascade 잠금은 **같은 트랜잭션 안에서는 재현되지 않는다** —
  # 자기 잠금은 건너뛸 대상도 기다릴 대상도 아니기 때문이다.
  def holding_row_lock(id)
    ActiveRecord::Base.connection_handler.clear_active_connections!
    lock_connection = ActiveRecord::Base.connection_pool.checkout
    lock_connection.begin_db_transaction
    lock_connection.exec_query("SELECT id FROM refresh_sessions WHERE id = #{lock_connection.quote(id)} FOR UPDATE")
    yield
  ensure
    if lock_connection
      begin
        lock_connection.rollback_db_transaction
      rescue StandardError
        nil
      end
      ActiveRecord::Base.connection_pool.checkin(lock_connection)
    end
  end

  describe "the batch statement (one statement, run once)" do
    it "deletes exactly LIMIT rows and drains 3 -> 2 -> 1 -> 0 one batch at a time" do
      purgeable(3.days)
      purgeable(2.days)
      purgeable(1.day)

      first = run_batch_sql(1)
      expect(RefreshSession.count).to eq(2)
      second = run_batch_sql(1)
      expect(RefreshSession.count).to eq(1)
      third = run_batch_sql(1)
      expect(RefreshSession.count).to eq(0)
      fourth = run_batch_sql(1)

      expect([ first.length, second.length, third.length, fourth.length ]).to eq([ 1, 1, 1, 0 ])
    end

    it "deletes oldest first even when heap order is the reverse of expires_at order" do
      # 물리적(heap) 순서를 `expires_at` 순서의 **역순**으로 만든다. 이 프로젝트가 이미
      # 두 번 겪은 함정이다 — 삽입 순서와 정렬 기준이 우연히 같으면 `ORDER BY` 를 지워도
      # 같은 결과가 나와서 테스트가 아무것도 지키지 못한다.
      newest = purgeable(1.day)
      middle = purgeable(2.days)
      oldest = purgeable(3.days)

      expect(RefreshSession.order(:ctid).pluck(:id)).to eq([ newest.id, middle.id, oldest.id ])
      expect(run_batch_sql(1)).to eq([ oldest.id ])
      expect(run_batch_sql(1)).to eq([ middle.id ])
      expect(run_batch_sql(1)).to eq([ newest.id ])
    end

    # 후보 선택을 CTE 로 감싼 것을 지키는 유일한 예제다.
    #
    # 기본 플래너 설정에서는 CTE 모양과 정본의 서브쿼리 모양이 **같은 결과를 낸다** —
    # PostgreSQL 18.6은 부수효과를 가진 서브쿼리를 `HashAggregate` 로 유일화하거나
    # `Materialize` 를 끼워 넣어 어느 쪽이든 한 번만 계산한다(3~50,000행 · LIMIT 1~1,000 ·
    # 인덱스/통계 유무의 11개 조합에서 실측, 전부 LIMIT 준수). 그래서 기본 설정으로 쓴
    # 테스트는 정본으로 되돌리는 뮤테이션에 **눈이 멀어 있다** — 이 프로젝트가 반복해서
    # 만나 온 "두 세계가 우연히 동일해 가드가 속 빈" 자리 그대로다.
    #
    # `enable_material` 을 끄면 두 세계가 갈린다: 서브쿼리 모양은 같은 문장이
    # `Subquery Scan ... loops=3` 이 되어 LIMIT 1 로 3행을 통째로 지우고, CTE 모양은
    # `CTE candidates ... loops=1` 로 정확히 1행만 지운다. CTE 가 사는 이유가 정확히
    # 그 차이 — 계획이 무엇이든 후보를 한 번만 계산한다는 보장 — 이므로 그 보장을 그대로
    # 단언한다. 다른 GUC 들은 유일화 경로(HashAggregate/Sort)를 막아 플래너가 그 보장에
    # 기대는 계획으로 내려가게 만드는 설정이다.
    #
    # 참고: `AS MATERIALIZED` **키워드**만 떼는 뮤테이션은 이 예제에서도 살아남는다.
    # 등가 뮤턴트이기 때문이다 — `FOR UPDATE` 를 담은 WITH 질의는 키워드가 없어도
    # 인라인되지 않는다(같은 적대적 설정에서 계획·결과 모두 동일함을 psql 로 확인).
    # 이 예제가 지키는 것은 키워드가 아니라 **CTE 로 감쌌다는 사실**이다.
    it "respects LIMIT even when the planner is denied every way to compute the subquery once" do
      purgeable(3.days)
      purgeable(2.days)
      purgeable(1.day)

      deleted = run_batch_sql(1, session_sql: [
        "SET LOCAL enable_hashagg = off",
        "SET LOCAL enable_sort = off",
        "SET LOCAL enable_hashjoin = off",
        "SET LOCAL enable_mergejoin = off",
        "SET LOCAL enable_material = off",
        "SET LOCAL enable_memoize = off"
      ])

      expect(deleted.length).to eq(1)
      expect(RefreshSession.count).to eq(2)
    end

    it "skips a candidate row another transaction holds and takes the next oldest instead" do
      oldest = purgeable(3.days)
      middle = purgeable(2.days)

      holding_row_lock(oldest.id) do
        # `SKIP LOCKED` 가 없으면 이 문장은 잠금을 **기다린다**. 그대로 두면 뮤테이션이
        # 무한 대기(테스트 hang)가 되어 실패로 드러나지 않으므로, 짧은 lock_timeout 을
        # 걸어 결정적인 실패로 바꾼다.
        deleted = run_batch_sql(1, session_sql: [ "SET LOCAL lock_timeout = '1000ms'" ])

        expect(deleted).to eq([ middle.id ])
      end

      expect(session_ids).to eq([ oldest.id ])
    end
  end

  describe "row selection" do
    it "only looks at expires_at: keeps every row that is not past the retention window" do
      purged = purgeable(1.second)
      just_expired = create(:refresh_session, user: user, expires_at: 1.minute.ago)
      still_valid = create(:refresh_session, user: user, expires_at: 30.days.from_now)
      # 폐기된 세션도, 회전으로 대체된 세션도 보존 기간 안이면 남는다 — `revoked_at` 이나
      # `replaced_by_id` 를 선택 조건에 넣으면 회전 체인의 살아 있는 링크가 끊긴다.
      revoked_recently = create(:refresh_session, user: user, expires_at: 1.hour.ago, revoked_at: 1.hour.ago)
      revoked_and_old = purgeable(2.days, revoked_at: 40.days.ago)

      result = described_class.perform_now

      expect(result.deleted).to eq(2)
      expect(session_ids).to match_array([ just_expired.id, still_valid.id, revoked_recently.id ])
      expect(RefreshSession.where(id: [ purged.id, revoked_and_old.id ])).to be_empty
    end

    it "clears replaced_by_id on a surviving chain row instead of deleting it" do
      replaced = purgeable(2.days)
      live = create(:refresh_session, user: user, expires_at: 30.days.from_now, replaced_by: replaced)

      expect(described_class.perform_now.deleted).to eq(1)

      expect(live.reload.replaced_by_id).to be_nil
      expect(session_ids).to eq([ live.id ])
    end
  end

  describe "batch accounting" do
    # 정본의 테스트가 놓친 관측량이다. 총 삭제 개수는 올바른 구현과 "첫 배치가 전부
    # 지우는" 버그 구현이 똑같이 3을 내지만, 배치 수는 4와 2로 갈린다.
    it "reports one batch per LIMIT-sized delete plus the final short batch" do
      3.times { |index| purgeable((index + 1).days) }

      result = described_class.perform_now(1)

      expect(result.deleted).to eq(3)
      expect(result.batches).to eq(4)
      expect(RefreshSession.count).to eq(0)
    end

    # 위 예제는 `batch_size` 가 1이라 "짧은 배치"와 "빈 배치"가 같은 것이 되어, 종료
    # 조건을 `batch_deleted.zero?` 로 바꾸는 뮤테이션에 **눈이 멀어 있다**(실측: 0 failures).
    # 3행을 2개씩 지우면 두 번째 배치가 1행짜리 짧은 배치라 거기서 멈춰야 하고, 종료
    # 조건이 "빈 배치"였다면 확인 배치가 한 번 더 돈다 — 그 차이가 batches 2와 3이다.
    it "stops on a short batch without spending another round trip" do
      3.times { |index| purgeable((index + 1).days) }

      result = described_class.perform_now(2)

      expect(result.deleted).to eq(3)
      expect(result.batches).to eq(2)
    end

    it "runs exactly one confirming batch when there is nothing to purge" do
      create(:refresh_session, user: user, expires_at: 30.days.from_now)

      result = described_class.perform_now

      expect(result.deleted).to eq(0)
      expect(result.batches).to eq(1)
    end

    it "stops at the batch cap and says so" do
      5.times { |index| purgeable((index + 1).days) }
      stub_const("#{described_class}::MAX_BATCHES", 2)
      allow(Rails.logger).to receive(:warn)

      result = described_class.perform_now(1)

      expect(result.deleted).to eq(2)
      expect(result.batches).to eq(2)
      expect(RefreshSession.count).to eq(3)
      expect(Rails.logger).to have_received(:warn).with(/stopped at the batch cap/)
    end
  end

  describe "batch_size guard" do
    # 정본·NestJS 모두 여기서 끊는다. `batch_size` 가 0이면 `deleted < batch_size` 가
    # `0 < 0` 으로 영원히 거짓이라 매 배치가 아무것도 지우지 못한 채 상한까지 빈 왕복을
    # 돌며 워커 슬롯을 붙잡는다.
    [ 0, -1, 1.5, nil, "10" ].each do |bad_batch_size|
      it "returns zero without touching the database for #{bad_batch_size.inspect}" do
        purgeable(2.days)
        allow(Rails.logger).to receive(:warn)
        statements = []
        subscription = ActiveSupport::Notifications.subscribe("sql.active_record") do |*, payload|
          statements << payload[:sql]
        end

        begin
          result = described_class.perform_now(bad_batch_size)
        ensure
          ActiveSupport::Notifications.unsubscribe(subscription)
        end

        expect(result.deleted).to eq(0)
        expect(result.batches).to eq(0)
        # "0을 돌려준다"만 단언하면 검사를 지워도 통과할 수 있다 — 잘못된 batch_size
        # 로도 결국 0행이 나오는 경우가 있기 때문이다. 검사가 **DB 를 건드리기 전에**
        # 있다는 것이 요구사항이므로 SQL 이 한 문장도 나가지 않았음을 본다.
        expect(statements).to be_empty
        expect(Rails.logger).to have_received(:warn).with(/batch_size must be a positive integer/)
        expect(RefreshSession.count).to eq(1)
      end
    end
  end

  describe "transaction ownership" do
    # Task 3 의 `Auth::RefreshSessions` 와 정반대의 계약이다. 주변 트랜잭션 안에서 돌면
    # 배치 커밋도 `SET LOCAL` 의 배치 한정성도 조용히 사라진다.
    it "refuses to run inside a caller transaction" do
      purgeable(2.days)

      expect { ActiveRecord::Base.transaction { described_class.perform_now } }
        .to raise_error(/must not run inside an open transaction/)

      expect(RefreshSession.count).to eq(1)
    end
  end

  describe "a batch that cannot take the cascade lock" do
    # 이 예제 하나가 세 가지를 한꺼번에 지킨다.
    #
    # 1. **배치마다 커밋한다.** 첫 배치가 지운 행은 두 번째 배치가 실패해도 남아야 한다.
    #    한 트랜잭션으로 전부 지우는 구현이었다면 첫 배치까지 롤백돼 3행이 그대로 남는다.
    # 2. **`SET LOCAL lock_timeout` 이 있다.** 없으면 배치는 잠금이 풀릴 때까지 매달린다
    #    (프로브 실측: lock_timeout 없이 5.25초를 기다렸다). 그래서 잡을 스레드에서
    #    돌리고 `join` 으로 상한을 걸어, 매달림을 hang 이 아니라 **실패**로 만든다.
    # 3. **오류를 삼키지 않는다.** 실패한 배치는 그대로 밖으로 나와 잡이 재시도를 받는다.
    #
    # 잠기는 행은 정리 대상이 **아니다** — 살아 있는 회전 체인 링크 A 이고, 배치가 지우려는
    # 것은 A 가 `replaced_by_id` 로 가리키는 만료 행 B 다. `SELECT ... FOR UPDATE SKIP
    # LOCKED` 는 자기가 고른 행(B)의 잠금만 피할 뿐 `ON DELETE SET NULL` cascade 가
    # 요구하는 A 의 잠금은 막아 주지 않는다. 그 사실이 lock_timeout 이 존재하는 이유이고,
    # 예외 메시지가 그 cascade UPDATE 를 그대로 지목하므로 `pg_stat_activity` 를 따로
    # 관측할 필요가 없다 — 예외 자체가 더 구체적인 증거다.
    it "commits the batches it finished, then raises instead of hanging" do
      first_target = purgeable(3.days)
      blocked_target = purgeable(2.days)
      chain_head = create(:refresh_session, user: user, expires_at: 30.days.from_now, replaced_by: blocked_target)

      holding_row_lock(chain_head.id) do
        job_thread = Thread.new do
          ActiveRecord::Base.connection_pool.with_connection { described_class.perform_now(1) }
        rescue StandardError => error
          error
        end
        @threads = [ job_thread ]

        expect(job_thread.join(5)).not_to be_nil, "batch hung on the cascade lock instead of timing out"
        raised = job_thread.value

        expect(raised).to be_a(ActiveRecord::LockWaitTimeout)
        expect(raised.message).to match(/replaced_by_id/)
      end

      # 첫 배치는 커밋됐고, 막힌 배치의 대상과 체인 머리는 그대로다.
      expect(RefreshSession.where(id: first_target.id)).to be_empty
      expect(session_ids).to match_array([ blocked_target.id, chain_head.id ])
    end
  end

  describe "job wiring" do
    it "maps the reference actor's retry policy onto Sidekiq" do
      # 정본: `@dramatiq.actor(max_retries=3, min_backoff=15_000)`.
      # Sidekiq 의 backoff 는 `job_retry.rb` 의 `(count**4) + 15` + jitter 라 최솟값이
      # 정확히 15초다. 남는 것은 재시도 횟수이고 그것이 이 옵션이다.
      expect(described_class.get_sidekiq_options["retry"]).to eq(3)
      expect(described_class.queue_name).to eq("default")
    end

    it "puts that retry count into the message Sidekiq actually reads" do
      # `sidekiq_options` 를 선언만 하고 끝나면 아무것도 보장되지 않는다 — 어댑터가
      # enqueue 하는 것은 이 클래스가 아니라 `Sidekiq::ActiveJob::Wrapper` 이고, 재시도
      # 판단은 `msg["retry"]` 로 이뤄진다. 이 클래스의 옵션이 거기까지 가는 경로는
      # `job_util.rb:49` 의 `item["wrapped"].get_sidekiq_options` merge 하나뿐이므로,
      # 그 정규화를 직접 돌려 결과를 본다(Redis 없이 도는 순수 함수다).
      normalizer = Object.new.extend(Sidekiq::JobUtil)
      item = normalizer.send(:normalize_item, {
        "class" => Sidekiq::ActiveJob::Wrapper,
        "wrapped" => described_class,
        "args" => [ {} ]
      })

      expect(item["retry"]).to eq(3)
    end

    it "targets the table the model is mapped to" do
      # `BATCH_SQL` 은 테이블 이름을 문자열로 담는다. 모델이 다른 테이블로 옮겨 가면
      # 그 SQL 은 조용히 엉뚱한(또는 없는) 테이블을 가리키게 된다.
      expect(RefreshSession.table_name).to eq("refresh_sessions")
      expect(described_class::BATCH_SQL).to include("refresh_sessions")
    end
  end
end
