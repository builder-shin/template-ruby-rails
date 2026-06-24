# frozen_string_literal: true

# Sidekiq 7+는 REDIS_URL 환경변수를 자동으로 읽음.
# 명시적 설정이 필요한 경우에만 아래 사용.

if defined?(Sidekiq)
  Sidekiq.configure_server do |config|
    config.on(:startup) do
      schedule_file = Rails.root.join("config", "sidekiq_cron.yml")
      if File.exist?(schedule_file)
        schedule = YAML.safe_load_file(schedule_file, permitted_classes: [ Date, Time ])
        Sidekiq::Cron::Job.load_from_hash!(schedule) if schedule.present?
      end
    end
  end
end
