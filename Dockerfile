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

ENV RAILS_ENV=production \
    BUNDLE_DEPLOYMENT=1 \
    BUNDLE_WITHOUT="development:test" \
    SECRET_KEY_BASE=dummy_for_asset_precompilation \
    DATABASE_HOST=localhost \
    AUTH_SERVICE_URL=http://auth.invalid

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
