# ---- build stage ----
FROM rust:1-slim-bookworm AS build
WORKDIR /app

# Cache dependencies separately from the application source.
COPY Cargo.toml Cargo.lock ./
RUN mkdir src && echo 'fn main() {}' > src/main.rs \
    && cargo build --release --locked \
    && rm -rf src target/release/deps/apibattle_api*

COPY openapi.yaml ./
COPY src ./src
RUN cargo build --release --locked

# ---- runtime stage ----
FROM debian:bookworm-slim
RUN apt-get update && apt-get install -y --no-install-recommends curl \
    && rm -rf /var/lib/apt/lists/* \
    && useradd --system --no-create-home app
COPY --from=build /app/target/release/apibattle_api /usr/local/bin/apibattle_api
USER app
EXPOSE 8080
HEALTHCHECK --interval=10s --timeout=3s --retries=3 CMD curl -fsS http://localhost:8080/health || exit 1
ENTRYPOINT ["/usr/local/bin/apibattle_api"]
