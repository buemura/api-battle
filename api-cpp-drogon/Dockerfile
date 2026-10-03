# ---- build stage ----
FROM ubuntu:24.04 AS build
ARG DROGON_VERSION=v1.9.12
RUN apt-get update && DEBIAN_FRONTEND=noninteractive apt-get install -y --no-install-recommends \
        build-essential cmake git ca-certificates \
        libjsoncpp-dev uuid-dev zlib1g-dev libssl-dev libc-ares-dev libbrotli-dev libpq-dev \
    && rm -rf /var/lib/apt/lists/*

RUN git clone --depth 1 --branch ${DROGON_VERSION} --recurse-submodules --shallow-submodules \
        https://github.com/drogonframework/drogon /tmp/drogon \
    && cmake -S /tmp/drogon -B /tmp/drogon/build -DCMAKE_BUILD_TYPE=Release \
        -DBUILD_EXAMPLES=OFF -DBUILD_CTL=OFF -DBUILD_TESTING=OFF \
        -DBUILD_POSTGRESQL=ON -DBUILD_MYSQL=OFF -DBUILD_SQLITE=OFF -DBUILD_REDIS=OFF \
    && cmake --build /tmp/drogon/build -j"$(nproc)" \
    && cmake --install /tmp/drogon/build \
    && rm -rf /tmp/drogon

WORKDIR /app
COPY CMakeLists.txt openapi.yaml ./
COPY src ./src
RUN cmake -S . -B build -DCMAKE_BUILD_TYPE=Release && cmake --build build -j"$(nproc)"

# ---- runtime stage ----
FROM ubuntu:24.04
RUN apt-get update && DEBIAN_FRONTEND=noninteractive apt-get install -y --no-install-recommends \
        libjsoncpp25 libuuid1 zlib1g libssl3t64 libc-ares2 libbrotli1 libpq5 curl \
    && rm -rf /var/lib/apt/lists/* \
    && useradd --system --no-create-home app
COPY --from=build /app/build/apibattle_api /usr/local/bin/apibattle_api
USER app
EXPOSE 8080
HEALTHCHECK --interval=10s --timeout=3s --retries=3 CMD curl -fsS http://localhost:8080/health || exit 1
ENTRYPOINT ["/usr/local/bin/apibattle_api"]
