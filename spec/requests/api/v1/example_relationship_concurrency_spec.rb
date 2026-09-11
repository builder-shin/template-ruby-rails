# frozen_string_literal: true

require "rails_helper"
require "database_cleaner/active_record"

RSpec.describe "Example relationship concurrency", type: :request do
  self.use_transactional_tests = false

  before do
    ActiveRecord::Base.connection_handler.clear_active_connections!
    DatabaseCleaner.clean_with(:truncation)
    mock_bearer_user
  end

  after do
    @threads&.each { |thread| thread.join(5) }
    ActiveRecord::Base.connection_handler.clear_active_connections!
    DatabaseCleaner.clean_with(:truncation)
    ActiveRecord::Base.connection_handler.clear_active_connections!
  end

  it "locks the parent row and makes concurrent same-tag additions idempotent" do
    example = create(:example)
    tag = create(:example_tag)
    path = "/api/v1/examples/#{example.id}/relationships/tags"
    body = { data: [ { type: "exampleTags", id: tag.id } ] }.to_json
    barrier = Concurrent::CyclicBarrier.new(2)
    backend_pids = Queue.new
    lock_connection = nil

    expect(
      Rails.application.routes.recognize_path(path, method: :post)
    ).to include(controller: "api/v1/examples", action: "add_tags_relationship")

    ActiveRecord::Base.connection_handler.clear_active_connections!
    lock_connection = ActiveRecord::Base.connection_pool.checkout
    lock_connection.begin_db_transaction
    quoted_id = lock_connection.quote(example.id)
    lock_connection.exec_query("SELECT id FROM examples WHERE id = #{quoted_id} FOR UPDATE")

    @threads = 2.times.map do
      Thread.new do
        ActiveRecord::Base.connection_pool.with_connection do |connection|
          session = ActionDispatch::Integration::Session.new(Rails.application)
          backend_pids << connection.raw_connection.backend_pid
          barrier.wait
          session.post(path, params: body, headers: jsonapi_headers.merge(auth_bearer_headers))
          session.response.status
        end
      end
    end

    pids = 2.times.map { backend_pids.pop }
    both_waited_for_parent_lock = wait_for_lock_waiters(pids)
    lock_connection.commit_db_transaction
    ActiveRecord::Base.connection_pool.checkin(lock_connection)
    lock_connection = nil

    statuses = @threads.map(&:value)

    expect(both_waited_for_parent_lock).to be(true)
    expect(statuses).to eq([ 204, 204 ])
    expect(ExampleTagging.where(example_id: example.id, tag_id: tag.id).count).to eq(1)
    expect(@threads).to all(satisfy { |thread| !thread.alive? })
  ensure
    if lock_connection
      lock_connection.rollback_db_transaction rescue nil
      ActiveRecord::Base.connection_pool.checkin(lock_connection)
    end
  end

  %i[patch put].each do |method|
    it "locks the parent before #{method} relationship replacement reads" do
      example = create(:example)
      tags = create_list(:example_tag, 2)
      backend_pids = Queue.new
      lock_connection = nil
      ActiveRecord::Base.connection_handler.clear_active_connections!
      lock_connection = ActiveRecord::Base.connection_pool.checkout
      lock_connection.begin_db_transaction
      lock_connection.exec_query("SELECT id FROM examples WHERE id = #{lock_connection.quote(example.id)} FOR UPDATE")
      @threads = tags.map do |tag|
        Thread.new do
          ActiveRecord::Base.connection_pool.with_connection do |connection|
            session = ActionDispatch::Integration::Session.new(Rails.application)
            backend_pids << connection.raw_connection.backend_pid
            data = { type: "examples", id: example.id, attributes: { title: "Replacement", status: "draft", score: 42 },
                     relationships: { tags: { data: [ { type: "exampleTags", id: tag.id } ] } } }
            session.public_send(method, "/api/v1/examples/#{example.id}", params: { data: data }.to_json,
              headers: jsonapi_headers.merge(auth_bearer_headers))
            session.response.status
          end
        end
      end
      pids = 2.times.map { backend_pids.pop }
      # PUT also takes an ID advisory lock, so its second request may wait there.
      parent_lock_observed = wait_for_parent_or_upsert_lock_waiters(pids)
      lock_connection.commit_db_transaction
      ActiveRecord::Base.connection_pool.checkin(lock_connection)
      lock_connection = nil
      expect(@threads.map(&:value)).to eq([ 200, 200 ])
      expect(parent_lock_observed).to be(true)
      final_ids = Example.find(example.id).tag_ids
      expect(final_ids.length).to eq(1)
      expect(tags.map(&:id)).to include(final_ids.first)
    ensure
      if lock_connection
        lock_connection.rollback_db_transaction rescue nil
        ActiveRecord::Base.connection_pool.checkin(lock_connection)
      end
    end
  end

  def wait_for_parent_or_upsert_lock_waiters(pids)
    deadline = Process.clock_gettime(Process::CLOCK_MONOTONIC) + 5
    loop do
      states = ActiveRecord::Base.connection_pool.with_connection do |connection|
        connection.exec_query("SELECT wait_event_type, query FROM pg_stat_activity WHERE pid IN (#{pids.map { |pid| Integer(pid) }.join(',')})").to_a
      end
      locked = states.all? { |state| state["wait_event_type"] == "Lock" }
      parent = states.any? { |state| state["query"].match?(/SELECT.+examples.+FOR UPDATE/i) }
      expected_queries = states.all? { |state| state["query"].match?(/SELECT.+examples.+FOR UPDATE|pg_advisory_xact_lock/i) }
      return true if states.length == pids.length && locked && parent && expected_queries
      return false if Process.clock_gettime(Process::CLOCK_MONOTONIC) >= deadline
      sleep 0.02
    end
  end

  def wait_for_lock_waiters(pids)
    deadline = Process.clock_gettime(Process::CLOCK_MONOTONIC) + 5
    loop do
      states = ActiveRecord::Base.connection_pool.with_connection do |connection|
        connection.exec_query(<<~SQL.squish).to_a
          SELECT pid::text, state, wait_event_type, wait_event, query
          FROM pg_stat_activity
          WHERE pid IN (#{pids.map { |pid| Integer(pid) }.join(", ")})
        SQL
      end
      waiting = states.select do |state|
        state["wait_event_type"] == "Lock" && state["query"].match?(/SELECT.+examples.+FOR UPDATE/i)
      end
      return true if waiting.length == pids.length
      return false if Process.clock_gettime(Process::CLOCK_MONOTONIC) >= deadline

      sleep 0.02
    end
  end
end
