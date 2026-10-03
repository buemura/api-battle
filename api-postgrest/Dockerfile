FROM postgrest/postgrest:v16.4 AS postgrest

# nginx (path mapping, static docs) + PostgREST (static binary) in one image,
# so the service exposes the same contract on :8080 as the other implementations.
FROM nginxinc/nginx-unprivileged:1.27-alpine
USER root
RUN apk add --no-cache bash curl tini postgresql17-client
COPY --from=postgrest /bin/postgrest /usr/local/bin/postgrest
COPY sql/api.sql nginx.conf /etc/apibattle/
COPY static/ /usr/share/apibattle/
COPY --chmod=755 entrypoint.sh /usr/local/bin/entrypoint.sh
USER nginx

ENV PGRST_DB_SCHEMAS=api \
    PGRST_DB_ANON_ROLE=web_anon \
    PGRST_DB_CHANNEL_ENABLED=false \
    PGRST_OPENAPI_MODE=disabled \
    PGRST_SERVER_HOST=127.0.0.1 \
    PGRST_SERVER_PORT=3000 \
    PGRST_LOG_LEVEL=error

EXPOSE 8080
HEALTHCHECK --interval=10s --timeout=3s --retries=3 CMD curl -fsS http://localhost:8080/health || exit 1
ENTRYPOINT ["/sbin/tini", "--", "/usr/local/bin/entrypoint.sh"]
