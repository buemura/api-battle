FROM alpine:3.22
RUN apk add --no-cache bash socat jq postgresql17-client pgbouncer tini curl \
    && adduser -S -H app
WORKDIR /app
COPY --chmod=755 entrypoint.sh handler.sh ./
COPY openapi.yaml docs.html ./
USER app
EXPOSE 8080
HEALTHCHECK --interval=10s --timeout=3s --retries=3 CMD curl -fsS http://localhost:8080/health || exit 1
ENTRYPOINT ["/sbin/tini", "--", "/app/entrypoint.sh"]
