# frozen_string_literal: true

# Sidekiq 7+는 REDIS_URL 환경변수를 자동으로 읽음.
# 명시적 설정이 필요한 경우에만 아래 사용.

if defined?(Sidekiq)
  Sidekiq.configure_server do |config|
    config.on(:startup) do
      schedule_file = Rails.root.join("config", "sidekiq_cron.yml")
      if File.exist?(schedule_file)
        schedule = YAML.safe_load_file(schedule_file, permitted_classes: [ Date, Time ]) || {}
        schedule.each do |name, entry|
          klass = Sidekiq::Cron::Support.safe_constantize(entry.fetch("class").to_s)
          unless klass.is_a?(Class) && (klass < ActiveJob::Base || klass.respond_to?(:perform_async))
            raise ArgumentError, "#{name}: #{entry.fetch('class')} is not an enqueueable job class"
          end
        end

        # Apply empty schedules too, removing old schedule-managed registrations.
        # sidekiq-cron returns validation errors instead of raising them.
        errors = Sidekiq::Cron::Job.load_from_hash!(schedule, source: "schedule")
        raise ArgumentError, "Invalid Sidekiq cron schedule: #{errors.inspect}" if errors.present?

        # Earlier releases omitted source: "schedule", so their default purge was
        # persisted as dynamic. Remove only that known registration on upgrade.
        unless schedule.key?("purge_expired_refresh_sessions")
          legacy = Sidekiq::Cron::Job.find("purge_expired_refresh_sessions")
          if legacy&.source == "dynamic" && legacy.klass == "PurgeExpiredRefreshSessionsJob" && legacy.cron == "0 * * * * UTC"
            legacy.destroy
          end
        end
      end
    end
  end
end
