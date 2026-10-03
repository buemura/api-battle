# ---- build stage ----
FROM elixir:1.19-otp-28-alpine AS build
WORKDIR /app
ENV MIX_ENV=prod

RUN mix local.hex --force && mix local.rebar --force

# Cache dependencies separately from the application source.
COPY mix.exs mix.lock ./
COPY config/config.exs ./config/
RUN mix deps.get --only prod && mix deps.compile

COPY priv ./priv
COPY lib ./lib
COPY config/runtime.exs ./config/
RUN mix release

# ---- runtime stage ----
# Must match the Alpine version of the build image (the release bundles ERTS).
FROM alpine:3.24
RUN apk add --no-cache libstdc++ libgcc ncurses-libs openssl \
    && addgroup -S app && adduser -S -G app app
COPY --from=build --chown=app:app /app/_build/prod/rel/apibattle /app
USER app
ENV LANG=C.UTF-8
EXPOSE 8080
HEALTHCHECK --interval=10s --timeout=3s --retries=3 CMD wget -qO- http://127.0.0.1:8080/health || exit 1
ENTRYPOINT ["/app/bin/apibattle", "start"]
