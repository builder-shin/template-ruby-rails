# Stage 1: Builder - install gems with build dependencies
FROM ruby:3.4.8-slim AS builder

RUN apt-get update -qq && \
    apt-get install -y --no-install-recommends \
    build-essential \
    libpq-dev \
    libvips-dev \
    libyaml-dev \
    curl \
    git \
    && rm -rf /var/lib/apt/lists/*

WORKDIR /app

COPY Gemfile Gemfile.lock ./

ENV BUNDLE_DEPLOYMENT=1 \
    BUNDLE_WITHOUT="development:test" \
    BUNDLE_PATH=/bundle

RUN bundle install --jobs 4 --retry 3

COPY . .

ENV RAILS_ENV=production \
    SECRET_KEY_BASE=dummy_for_asset_precompilation

RUN bundle exec rails assets:precompile || true

# Stage 2: Runtime - lean production image
FROM ruby:3.4.8-slim

RUN apt-get update -qq && \
    apt-get install -y --no-install-recommends \
    libpq5 \
    libvips42 \
    curl \
    && rm -rf /var/lib/apt/lists/*

RUN groupadd -r app && useradd -r -g app -m app

WORKDIR /app

COPY --from=builder /bundle /bundle
COPY --from=builder --chown=app:app /app /app

ENV RAILS_ENV=production \
    RAILS_SERVE_STATIC_FILES=true \
    RAILS_LOG_TO_STDOUT=true \
    BUNDLE_PATH=/bundle \
    BUNDLE_DEPLOYMENT=1 \
    BUNDLE_WITHOUT="development:test" \
    PORT=4000

EXPOSE 4000

USER app

HEALTHCHECK --interval=30s --timeout=3s --start-period=40s --retries=3 \
  CMD curl -f http://localhost:${PORT}/health || exit 1

CMD ["sh", "-c", "bundle exec rails db:migrate && bundle exec puma -C config/puma.rb"]
