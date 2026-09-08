require "active_support/core_ext/integer/time"

Rails.application.configure do
  # Settings specified here will take precedence over those in config/application.rb.

  # Code is not reloaded between requests.
  config.enable_reloading = false

  # Eager load code on boot. This eager loads most of Rails and
  # your application in memory, allowing both threaded web servers
  # and those relying on copy on write to perform better.
  # Rake tasks automatically ignore this option for performance.
  config.eager_load = true

  # Full error reports are disabled and caching is turned on.
  config.consider_all_requests_local = false
  config.action_controller.perform_caching = true

  # Ensures that a master key has been made available in ENV["RAILS_MASTER_KEY"], config/master.key, or an environment
  # key such as config/credentials/production.key. This key is used to decrypt credentials (and other encrypted files).
  # config.require_master_key = true

  # Disable serving static files from `public/`, relying on NGINX/Apache to do so instead.
  # config.public_file_server.enabled = false

  # Compress CSS using a preprocessor.
  # config.assets.css_compressor = :sass

  # Do not fall back to assets pipeline if a precompiled asset is missed.
  config.assets.compile = false

  # Enable serving of images, stylesheets, and JavaScripts from an asset server.
  # config.asset_host = "http://assets.example.com"

  # Specifies the header that your server uses for sending files.
  # config.action_dispatch.x_sendfile_header = "X-Sendfile" # for Apache
  # config.action_dispatch.x_sendfile_header = "X-Accel-Redirect" # for NGINX

  # Store uploaded files on the local file system (see config/storage.yml for options).
  config.active_storage.service = ENV.fetch("ACTIVE_STORAGE_SERVICE", "amazon").to_sym

  # Mount Action Cable outside main process or domain.
  # config.action_cable.mount_path = nil
  # config.action_cable.url = "wss://example.com/cable"
  # config.action_cable.allowed_request_origins = [ "http://example.com", /http:\/\/example.*/ ]

  # Assume all access to the app is happening through a SSL-terminating reverse proxy.
  # Railway terminates SSL at the reverse proxy level, so Puma receives plain HTTP.
  config.assume_ssl = true

  # Force all access to the app over SSL, use Strict-Transport-Security, and use secure cookies.
  #
  # 기본은 켜짐이다 — 운영에서 실수로 꺼지면 그 자체로 보안 결함이므로, 끄는 쪽만
  # 화이트리스트로 인식한다. RAILS_FORCE_SSL을 "false" 또는 "0"(대소문자 무관)으로
  # 명시했을 때만 꺼지고, 그 외 값이나 미설정은 전부 켜짐이다 — 오타나 빈 문자열로
  # 꺼지는 사고를 막는다.
  #
  # 참고: 바로 위 assume_ssl = true 때문에 이 값이 켜져 있어도 평문 HTTP 요청이
  # https로 리다이렉트되지는 않는다 — request.ssl?를 항상 true로 취급해서 force_ssl의
  # 리다이렉트 분기 자체를 안 탄다(컨테이너 내부망에서 직접 실측 확인). 다만
  # Strict-Transport-Security 헤더는 이 값에만 달려 있으므로, TLS가 없는 환경(E2E 등)
  # 에서 그 헤더를 보내고 싶지 않을 때 여기서 명시적으로 끌 수 있게 열어 둔다.
  force_ssl_explicitly_disabled = %w[false 0].include?(ENV["RAILS_FORCE_SSL"].to_s.strip.downcase)
  config.force_ssl = !force_ssl_explicitly_disabled

  # Skip http-to-https redirect for health check endpoints (used by Railway internal health checks).
  config.ssl_options = { redirect: { exclude: ->(request) { request.path.start_with?("/health") } } }

  # Log to STDOUT by default
  config.logger = ActiveSupport::Logger.new(STDOUT)
    .tap  { |logger| logger.formatter = ::Logger::Formatter.new }
    .then { |logger| ActiveSupport::TaggedLogging.new(logger) }

  # Prepend all log lines with the following tags.
  config.log_tags = [ :request_id ]

  # "info" includes generic and useful information about system operation, but avoids logging too much
  # information to avoid inadvertent exposure of personally identifiable information (PII). If you
  # want to log everything, set the level to "debug".
  config.log_level = ENV.fetch("RAILS_LOG_LEVEL", "info")

  # Use a different cache store in production.
  # config.cache_store = :mem_cache_store

  # Use a real queuing backend for Active Job (and separate queues per environment).
  # config.active_job.queue_adapter = :resque
  # config.active_job.queue_name_prefix = "template_production"

  # Disable caching for Action Mailer templates even if Action Controller
  # caching is enabled.
  config.action_mailer.perform_caching = false

  # Ignore bad email addresses and do not raise email delivery errors.
  # Set this to true and configure the email server for immediate delivery to raise delivery errors.
  # config.action_mailer.raise_delivery_errors = false

  # Enable locale fallbacks for I18n (makes lookups for any locale fall back to
  # the I18n.default_locale when a translation cannot be found).
  config.i18n.fallbacks = true

  # Don't log any deprecations.
  config.active_support.report_deprecations = false

  # Do not dump schema after migrations.
  config.active_record.dump_schema_after_migration = false

  # Enable DNS rebinding protection and other `Host` header attacks.
  #
  # 기본은 오늘과 동일하게 ["localhost"]다. 빈 문자열은 "설정 안 함"으로 취급한다
  # (.presence) — ENV.fetch만 쓰면 ALLOWED_HOSTS=(빈 값)일 때 "".split(",")가 []가
  # 되어 host 검사가 통째로 꺼진다. 운영에서 조용히 열리는 채로 아무 흔적도 안 남는
  # 보안 구멍이라, development.rb와 같은 모양의 가드를 여기도 넣는다.
  config.hosts =
    if (allowed_hosts = ENV["ALLOWED_HOSTS"].presence)
      allowed_hosts.split(",")
    else
      [ "localhost" ]
    end
  # Skip DNS rebinding protection for the default health check endpoint.
  config.host_authorization = { exclude: ->(request) { request.path.start_with?("/health") } }
end
