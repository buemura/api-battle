# ---- build stage ----
FROM ghcr.io/gleam-lang/gleam:v1.14.0-erlang-alpine AS build
WORKDIR /app

# Cache dependencies separately from the application source.
COPY gleam.toml manifest.toml ./
RUN gleam deps download

COPY priv ./priv
COPY src ./src
RUN gleam export erlang-shipment

# ---- runtime stage ----
FROM erlang:28-alpine
RUN addgroup -S app && adduser -S -G app app
COPY --from=build /app/build/erlang-shipment /app
USER app
EXPOSE 8080
HEALTHCHECK --interval=10s --timeout=3s --retries=3 CMD wget -qO- http://127.0.0.1:8080/health || exit 1
ENTRYPOINT ["/app/entrypoint.sh", "run"]
