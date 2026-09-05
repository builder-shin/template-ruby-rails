# frozen_string_literal: true

require "rails_helper"
require "sidekiq/cron"
require "fugit"

# `config/sidekiq_cron.yml` 의 항목은 **어떤 게이트도 검사하지 않는다.** rspec·rubocop·
# brakeman 중 무엇도 YAML 안의 `class:` 문자열을 보지 않고, 부팅도 멈추지 않는다.
# sidekiq-cron 2.3.1을 직접 읽고 컨테이너에서 실행해 확인한 실제 동작:
#
#   - `Job#valid?` 가 부르는 `klass_valid`(`job.rb:467`)는 `@klass` 가 **비어 있지 않은
#     String 인지만** 본다. 상수가 실재하는지는 보지 않는다.
#   - `load_from_hash!`(`job.rb:253`)는 오류를 raise 하지 않고 `{name => [errors]}` Hash 를
#     **반환**한다. `config/initializers/sidekiq.rb:12` 는 그 반환값을 버린다.
#
# 그래서 실측 결과는 이렇다 — 존재하지 않는 `class: "TotallyDoesNotExistJob"` 은 오류
# 없이 **등록되고**(`load_from_hash!` 반환값 `{}`), 깨진 `cron:` 은 오류 Hash 만 남기고
# **조용히 누락된다.** 둘 다 Sidekiq 서버는 정상적으로 뜬다. 정리 작업이 영영 돌지
# 않는다는 사실은 아무 신호 없이 운영에서만 드러난다.
#
# 이 스펙이 그 자리를 메운다. Redis 없이 도는 것이 요구사항이다 — CI 의 test job
# (`.github/workflows/ci.yml`)에는 Postgres 만 있고 Redis 가 없으며, `Sidekiq::Cron::Job.new`
# 는 생성자에서 Redis 를 읽으므로(`status_from_redis`) 그 클래스를 쓸 수 없다.
RSpec.describe "Sidekiq cron schedule contract" do
  # 초기화자와 **같은 방식으로** 읽는다(`config/initializers/sidekiq.rb:11`). 여기서
  # 다르게 읽으면 이 스펙이 통과하는 파일과 서버가 읽는 파일이 갈릴 수 있다.
  let(:schedule) do
    YAML.safe_load_file(Rails.root.join("config", "sidekiq_cron.yml"), permitted_classes: [ Date, Time ]) || {}
  end

  it "schedules the expired refresh session purge" do
    expect(schedule).to have_key("purge_expired_refresh_sessions")
    expect(schedule.fetch("purge_expired_refresh_sessions").fetch("class"))
      .to eq("PurgeExpiredRefreshSessionsJob")
  end

  it "resolves every class: to a constant that sidekiq-cron can actually enqueue" do
    expect(schedule).not_to be_empty

    schedule.each do |name, entry|
      # sidekiq-cron 자신이 enqueue 시점에 쓰는 resolver 를 그대로 쓴다(`job.rb:135`).
      # 우리가 `Object.const_get` 으로 따로 흉내 내면 네임스페이스 해석 규칙이 갈릴 수 있다.
      klass = Sidekiq::Cron::Support.safe_constantize(entry.fetch("class").to_s)

      expect(klass).not_to be_nil, "#{name}: class #{entry.fetch("class").inspect} does not resolve to a constant"

      # `enqueue!` 는 상수가 ActiveJob 인지(`is_active_job?`, `job.rb:157`) 로 분기해
      # `perform_later` 또는 `perform_async` 를 부른다. 둘 중 어느 쪽도 아니면 상수가
      # 존재해도 enqueue 가 실패한다.
      enqueueable = klass < ActiveJob::Base || klass.respond_to?(:perform_async)
      expect(enqueueable).to be(true), "#{name}: #{klass} is neither an ActiveJob nor a Sidekiq::Job"
    end
  end

  it "parses every cron: with the same parser sidekiq-cron uses" do
    # `do_parse_cron`(`job.rb:609`)은 설정된 모드로 분기한다. 기본값 `:single` 이면
    # `Fugit.do_parse_cronish` 다. 모드가 바뀌면 이 스펙이 검사하는 파서와 서버가 쓰는
    # 파서가 갈리므로, 갈리는 순간 여기서 먼저 실패하게 고정한다.
    expect(Sidekiq::Cron.configuration.natural_cron_parsing_mode).to eq(:single)

    schedule.each do |name, entry|
      expect { Fugit.do_parse_cronish(entry.fetch("cron").to_s) }
        .not_to raise_error, "#{name}: cron #{entry.fetch("cron").inspect} does not parse"
    end
  end
end
