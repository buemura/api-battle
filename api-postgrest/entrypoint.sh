#!/usr/bin/env bash
# Applies the API schema, then runs PostgREST and nginx side by side. If either
# process exits, the other is stopped and the container exits with its status.
set -euo pipefail

# libpq environment, shared by psql and PostgREST (PGRST_DB_URI is left at its
# "postgresql://" default so these are picked up).
export PGHOST="${DB_HOST:-localhost}"
export PGPORT="${DB_PORT:-5432}"
export PGDATABASE="${DB_NAME:-apibattle}"
export PGUSER="${DB_USER:-apibattle}"
export PGPASSWORD="${DB_PASSWORD:-apibattle}"
export PGRST_DB_POOL="${DB_POOL_SIZE:-10}"
PORT="${PORT:-8080}"

for _ in $(seq 30); do
  pg_isready -q && break
  echo "waiting for postgres at ${PGHOST}:${PGPORT}..." >&2
  sleep 1
done

PGOPTIONS="-c client_min_messages=warning" psql --quiet --no-psqlrc --single-transaction -v ON_ERROR_STOP=1 -f /etc/apibattle/api.sql

sed "s/__PORT__/${PORT}/" /etc/apibattle/nginx.conf > /tmp/nginx.conf

postgrest &
pgrst_pid=$!
nginx -c /tmp/nginx.conf -g 'daemon off;' &
nginx_pid=$!

shutdown() {
  kill -QUIT "$nginx_pid" 2>/dev/null || true  # graceful: finish in-flight requests
  kill -TERM "$pgrst_pid" 2>/dev/null || true
}
trap shutdown TERM INT

status=0
wait -n || status=$?
shutdown
wait || true
exit "$status"
