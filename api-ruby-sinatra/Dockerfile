# ---- dependencies ----
FROM ruby:4.0-slim AS base
WORKDIR /app
ENV APP_ENV=production \
    BUNDLE_DEPLOYMENT=1 \
    BUNDLE_WITHOUT=development:test \
    BUNDLE_PATH=/usr/local/bundle

FROM base AS deps
RUN apt-get update -qq \
 && apt-get install -y --no-install-recommends build-essential \
 && rm -rf /var/lib/apt/lists/*
COPY Gemfile Gemfile.lock ./
RUN bundle install --jobs 4 \
 && rm -rf "$BUNDLE_PATH"/ruby/*/cache
COPY . .

# ---- runtime ----
FROM base
ENV RUBY_YJIT_ENABLE=1 \
    MALLOC_ARENA_MAX=2
RUN useradd --system --no-create-home app
COPY --from=deps /usr/local/bundle /usr/local/bundle
COPY --from=deps --chown=app:app /app /app
USER app
EXPOSE 8080
HEALTHCHECK --interval=10s --timeout=3s --start-period=15s --retries=3 \
  CMD ruby -rnet/http -e 'exit Net::HTTP.get_response(URI("http://localhost:#{ENV.fetch("PORT", 8080)}/health")).is_a?(Net::HTTPSuccess)'
CMD ["bundle", "exec", "puma", "-C", "config/puma.rb"]
