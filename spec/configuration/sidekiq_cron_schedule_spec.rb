# frozen_string_literal: true

require "rails_helper"
require "sidekiq/cron"

RSpec.describe "Sidekiq cron schedule contract" do
  let(:schedule_file) { Rails.root.join("config", "sidekiq_cron.yml") }
  let(:schedule) { YAML.safe_load_file(schedule_file, permitted_classes: [ Date, Time ]) }
  let(:hourly_purge) do
    {
      "purge_expired_refresh_sessions" => {
        "cron" => "0 * * * * UTC",
        "class" => "PurgeExpiredRefreshSessionsJob",
        "queue" => "default"
      }
    }
  end

  before do
    allow(Sidekiq::Cron::Job).to receive(:find).with("purge_expired_refresh_sessions").and_return(nil)
  end

  # Exercise the real initializer, replacing only the server lifecycle and Redis
  # boundary. CI runs configuration specs without a Redis service.
  def run_startup
    startup = nil
    server = double("Sidekiq server configuration")
    allow(server).to receive(:on).with(:startup) { |&callback| startup = callback }
    allow(Sidekiq).to receive(:configure_server).and_yield(server)
    load Rails.root.join("config", "initializers", "sidekiq.rb")
    startup.call
  end

  it "ships without an automatically scheduled purge" do
    expect(schedule).to eq({})
  end

  it "applies an empty schedule to remove previously persisted scheduled jobs" do
    allow(YAML).to receive(:safe_load_file).with(schedule_file, permitted_classes: [ Date, Time ]).and_return({})
    expect(Sidekiq::Cron::Job).to receive(:load_from_hash!).with({}, source: "schedule").and_return({})

    run_startup
  end

  it "treats a comments-only schedule as empty" do
    allow(YAML).to receive(:safe_load_file).with(schedule_file, permitted_classes: [ Date, Time ]).and_return(nil)
    expect(Sidekiq::Cron::Job).to receive(:load_from_hash!).with({}, source: "schedule").and_return({})

    run_startup
  end

  it "loads an explicitly configured hourly purge" do
    allow(YAML).to receive(:safe_load_file).with(schedule_file, permitted_classes: [ Date, Time ]).and_return(hourly_purge)
    expect(Sidekiq::Cron::Job).to receive(:load_from_hash!).with(hourly_purge, source: "schedule").and_return({})

    run_startup
  end

  it "rejects a job class that cannot be enqueued before touching Redis" do
    hourly_purge.fetch("purge_expired_refresh_sessions")["class"] = "MissingPurgeJob"
    allow(YAML).to receive(:safe_load_file).with(schedule_file, permitted_classes: [ Date, Time ]).and_return(hourly_purge)
    expect(Sidekiq::Cron::Job).not_to receive(:load_from_hash!)

    expect { run_startup }.to raise_error(ArgumentError, /MissingPurgeJob/)
  end

  it "raises when sidekiq-cron reports an invalid schedule" do
    hourly_purge.fetch("purge_expired_refresh_sessions")["cron"] = "invalid cron"
    allow(YAML).to receive(:safe_load_file).with(schedule_file, permitted_classes: [ Date, Time ]).and_return(hourly_purge)
    allow(Sidekiq::Cron::Job).to receive(:load_from_hash!).with(hourly_purge, source: "schedule")
      .and_return("purge_expired_refresh_sessions" => [ "invalid cron" ])

    expect { run_startup }.to raise_error(ArgumentError, /purge_expired_refresh_sessions/)
  end

  it "removes the old default purge that earlier versions registered as dynamic" do
    legacy = instance_double(Sidekiq::Cron::Job, source: "dynamic", klass: "PurgeExpiredRefreshSessionsJob", cron: "0 * * * * UTC")
    allow(YAML).to receive(:safe_load_file).with(schedule_file, permitted_classes: [ Date, Time ]).and_return({})
    allow(Sidekiq::Cron::Job).to receive(:load_from_hash!).with({}, source: "schedule").and_return({})
    allow(Sidekiq::Cron::Job).to receive(:find).with("purge_expired_refresh_sessions").and_return(legacy)
    expect(legacy).to receive(:destroy)

    run_startup
  end

  it "preserves a custom dynamic schedule with the same name" do
    custom = instance_double(Sidekiq::Cron::Job, source: "dynamic", klass: "PurgeExpiredRefreshSessionsJob", cron: "0 0 * * * UTC")
    allow(YAML).to receive(:safe_load_file).with(schedule_file, permitted_classes: [ Date, Time ]).and_return({})
    allow(Sidekiq::Cron::Job).to receive(:load_from_hash!).with({}, source: "schedule").and_return({})
    allow(Sidekiq::Cron::Job).to receive(:find).with("purge_expired_refresh_sessions").and_return(custom)
    expect(custom).not_to receive(:destroy)

    run_startup
  end
end
