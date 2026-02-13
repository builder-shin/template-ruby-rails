require_relative "boot"

require "rails/all"

# Require the gems listed in Gemfile, including any gems
# you've limited to :test, :development, or :production.
Bundler.require(*Rails.groups)

module Template
  class Application < Rails::Application
    # Initialize configuration defaults for originally generated Rails version.
    config.load_defaults 7.2

    # Please, add to the `ignore` list any other `lib` subdirectories that do
    # not contain `.rb` files, or that should not be reloaded or eager loaded.
    # Common ones are `templates`, `generators`, or `middleware`, for example.
    config.autoload_lib(ignore: %w[assets tasks])

    # Configuration for the application, engines, and railties goes here.
    #
    # These settings can be overridden in specific environments using the files
    # in config/environments, which are processed later.
    #
    config.time_zone = "Asia/Seoul"
    # config.eager_load_paths << Rails.root.join("extras")

    # default encoding 설정
    config.encoding = "utf-8"

    # 사이드킥을 사용하도록 설정
    config.active_job.queue_adapter = :sidekiq

    # Cookie / Session 설정
    config.session_store :cookie_store, key: "_template_session", domain: :all, secure: Rails.env.production?, httponly: true, same_site: :none
    config.middleware.use ActionDispatch::Cookies
    config.middleware.use config.session_store

    # Callback 설정
    config.action_controller.raise_on_missing_callback_actions = false

    # API only 설정
    config.api_only = true

    # 한글화 설정
    config.i18n.default_locale = :ko
  end
end

if Rails.env.test? || Rails.env.development?
  RSpec.configure do |config|
    config.rswag_dry_run = false
  end
end
