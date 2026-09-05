# syntax=docker/dockerfile:1

FROM ruby:3.4.8-slim AS base

RUN apt-get update -qq && \
    apt-get install -y --no-install-recommends \
    curl \
    libpq5 \
    libvips42 \
    && rm -rf /var/lib/apt/lists/*

WORKDIR /app

ENV BUNDLE_PATH=/bundle \
    PORT=4000

FROM base AS bundle

RUN apt-get update -qq && \
    apt-get install -y --no-install-recommends \
    build-essential \
    git \
    libpq-dev \
    libvips-dev \
    libyaml-dev \
    && rm -rf /var/lib/apt/lists/*

COPY Gemfile Gemfile.lock ./

FROM bundle AS development

ENV RAILS_ENV=development \
    BUNDLE_WITHOUT=""

RUN bundle install --jobs 4 --retry 3

COPY . .

EXPOSE 4000

CMD ["bundle", "exec", "puma", "-C", "config/puma.rb"]

FROM bundle AS production-bundle

# assets:precompile 은 config/environment.rb 를 로드하므로 **모든 initializer 가
# 빌드 시점에 실행된다.** 부팅을 중단시키는 환경변수를 요구하는 initializer 가
# 있으면 여기에 빌드 전용 더미를 넣어야 이미지가 빌드된다 —
# SECRET_KEY_BASE 가 원래 그 이유로 있던 자리이고, JWT_SECRET_KEY 도 같다
# (config/initializers/auth.rb 는 값이 없으면 raise 한다. 코드에 기본값을 두지
# 않는 것이 의도된 동작이다).
#
# JWT_SECRET_KEY 더미는 **32바이트 이상**이어야 한다 — auth.rb 는 존재 여부와
# 길이를 따로 검사하므로(:8 과 :9) 짧은 더미는 두 번째 검사에서 다시 막힌다.
#
# 앞으로 부팅을 막는 환경변수를 새로 추가하면 이 목록에도 더미를 추가해라.
# 잊으면 rspec/rubocop/brakeman 은 전부 통과하고 **CI 의 container 작업에서만**
# 드러난다(그 작업이 실제로 이미지를 빌드하는 유일한 게이트다).
#
# 이 더미들은 최종 이미지에 남지 않는다 — 아래 `FROM base AS production` 은
# 이 스테이지를 상속하지 않고 /bundle 과 /app 만 COPY 해 온다. 운영 값은
# 컨테이너 실행 시점에 주입해야 한다.
ENV RAILS_ENV=production \
    BUNDLE_DEPLOYMENT=1 \
    BUNDLE_WITHOUT="development:test" \
    SECRET_KEY_BASE=dummy_for_asset_precompilation \
    JWT_SECRET_KEY=dummy_jwt_secret_for_asset_precompilation_only \
    DATABASE_HOST=localhost

RUN bundle install --jobs 4 --retry 3

COPY . .

RUN bundle exec rails assets:precompile

FROM base AS production

RUN groupadd -r app && useradd -r -g app -m app

COPY --from=production-bundle /bundle /bundle
COPY --from=production-bundle --chown=app:app /app /app

ENV RAILS_ENV=production \
    RAILS_SERVE_STATIC_FILES=true \
    RAILS_LOG_TO_STDOUT=true \
    BUNDLE_DEPLOYMENT=1 \
    BUNDLE_WITHOUT="development:test"

EXPOSE 4000

USER app

HEALTHCHECK --interval=30s --timeout=3s --start-period=40s --retries=3 \
  CMD curl -f http://localhost:${PORT}/health/ready || exit 1

CMD ["bundle", "exec", "puma", "-C", "config/puma.rb"]
