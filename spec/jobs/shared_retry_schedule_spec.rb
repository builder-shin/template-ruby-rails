# frozen_string_literal: true

require "rails_helper"
require "sidekiq/job_retry"
require "sidekiq/capsule"

RSpec.describe "Shared retry schedule" do
  include ActiveSupport::Testing::TimeHelpers
  [ ProcessExampleJob, PurgeExpiredRefreshSessionsJob ].each do |job_class|
    [ false, true ].each do |jitter_high|
      it "schedules three #{job_class} retries with #{jitter_high ? 'maximum' : 'minimum'} jitter" do
        retry_handler = Sidekiq::JobRetry.new(Sidekiq.default_configuration.default_capsule)
        scheduled = []
        redis = double("retry Redis connection")
        allow(redis).to receive(:zadd) { |_key, score, _payload| scheduled << score.to_f }
        allow(retry_handler).to receive(:redis).and_yield(redis)
        allow(retry_handler).to receive(:rand) { |upper| jitter_high ? upper - 1 : 0 }
        allow(retry_handler).to receive(:retries_exhausted)
        message = { "class" => "Sidekiq::ActiveJob::Wrapper", "wrapped" => job_class.name,
                    "args" => [], "retry" => job_class.get_sidekiq_options.fetch("retry") }
        travel_to(Time.utc(2026, 9, 11)) do
          4.times do
            retry_handler.send(:process_retry, nil, message, "default", RuntimeError.new("database unavailable"))
          end
          expected = jitter_high ? [ 24, 49, 89 ] : [ 15, 30, 60 ]
          expect(scheduled.map { |timestamp| timestamp - Time.now.to_f }).to eq(expected)
        end
        expect(retry_handler).to have_received(:retries_exhausted).once
        expect(message.fetch("error_message")).to eq("database unavailable")
      end
    end
  end
end
