source "https://rubygems.org"

# Bundle edge Rails instead: gem "rails", github: "rails/rails", branch: "main"
gem "rails", "~> 8.1.2"
# The original asset pipeline for Rails [https://github.com/rails/sprockets-rails]
gem "sprockets-rails"
# Use sqlite3 as the database for Active Record
# gem "sqlite3", ">= 1.4"
gem "pg"
# Use the Puma web server [https://github.com/puma/puma]
gem "puma", ">= 5.0"
# Use JavaScript with ESM import maps [https://github.com/rails/importmap-rails]
gem "importmap-rails"
# Hotwire's SPA-like page accelerator [https://turbo.hotwired.dev]
gem "turbo-rails"
# Hotwire's modest JavaScript framework [https://stimulus.hotwired.dev]
gem "stimulus-rails"
# Build JSON APIs with ease [https://github.com/rails/jbuilder]
gem "jbuilder"
# Use Redis adapter to run Action Cable in production
# gem "redis", ">= 4.0.1"

# Use Kredis to get higher-level data types in Redis [https://github.com/rails/kredis]
# gem "kredis"

# Use Active Model has_secure_password [https://guides.rubyonrails.org/active_model_basics.html#securepassword]
gem "bcrypt", "~> 3.1.7"

# Windows does not include zoneinfo files, so bundle the tzinfo-data gem
gem "tzinfo-data"

# Reduces boot times through caching; required in config/boot.rb
gem "bootsnap", require: false

# Use Active Storage variants [https://guides.rubyonrails.org/active_storage_overview.html#transforming-images]
gem "image_processing", "~> 1.2"
# AWS S3 for Active Storage
gem "aws-sdk-s3", "~> 1.0"

group :development, :test do
  # See https://guides.rubyonrails.org/debugging_rails_applications.html#debugging-with-the-debug-gem
  gem "debug", platforms: %i[ mri windows ], require: "debug/prelude"

  # Static analysis for security vulnerabilities [https://brakemanscanner.org/]
  gem "brakeman", require: false

  # Omakase Ruby styling [https://github.com/rails/rubocop-rails-omakase/]
  gem "rubocop-rails-omakase", require: false
end

group :development do
  # Use console on exceptions pages [https://github.com/rails/web-console]
  gem "web-console"
end

group :test do
  # Use system testing [https://guides.rubyonrails.org/testing.html#system-testing]
  gem "capybara"
  gem "selenium-webdriver"
end

# 모든 환경에서 사용하는 Gem
# ENV 설정을 위한 Gem
gem "dotenv-rails"
# JSON API를 위한 Gem
gem "jsonapi.rb"
# JSON API Serializer를 위한 Gem
gem "jsonapi-serializer"
# Pagination을 위한 Gem
gem "kaminari"
# CORS 설정을 위한 Gem
gem "rack-cors"
# Rate Limiting을 위한 Gem
gem "rack-attack"
# Swagger를 위한 Gem
gem "rswag"
# Sentry를 위한 Gem
gem "sentry-rails"
gem "sentry-ruby"
# 백그라운드 작업을 위한 Gem
gem "sidekiq", ">= 7.3.3"
gem "sidekiq-cron", "~> 2.0"
gem "sendgrid-ruby", "~> 6.7"
# zip 파일을 핸들링하기 위한 Gem
gem "rubyzip"
# 웹소켓 통신을 위한 Gem
gem "actioncable"
# 검색 및 필터링 기능을 위한 Gem
gem "ransack"
# 인증(로그인/회원가입/ETC)을 위한 Gem
# HTTP 클라이언트 (외부 API 호출용)
gem "faraday", "~> 2.0"
gem "faraday-retry"
# 한글화를 위한 Gem
gem "rails-i18n"
# 환경 변수를 설정하기 위한 Gem
gem "ostruct"
#  로그 포맷 통일을 위한 Gem
gem 'lograge'

# 개발 / 테스트 환경 Gem
group :development, :test do
  # 테스트를 위한 Gem
  gem "rspec-rails"
  # 테스트 데이터를 만들기 위한 Gem
  gem "factory_bot_rails"
  # 무작위 데이터를 만들기 위한 Gem
  gem "faker"
  # 데이터베이스를 초기화하기 위한 Gem
  gem "database_cleaner-active_record"
  # 모델 테스트를 더 간결하게 작성하기 위한 Gem
  gem "shoulda-matchers"
end

# 개발 환경 Gem
group :development do
  # 스타일 통일을 위한 Gem
  gem "ruby-lsp-rails"
end

# 테스트 환경 Gem
group :test do
  # HTTP 요청 모킹
  gem "webmock"
end
