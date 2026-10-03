#!/usr/bin/env bash
# Starts a local PgBouncer (the connection pool, since every request spawns a
# fresh psql) and then socat, which forks handler.sh per connection.
set -euo pipefail

: "${PORT:=8080}"
: "${DB_HOST:=localhost}" "${DB_PORT:=5432}" "${DB_NAME:=apibattle}"
: "${DB_USER:=apibattle}" "${DB_PASSWORD:=apibattle}" "${DB_POOL_SIZE:=10}"
: "${MAX_CONNECTIONS:=512}"

run_dir=$(mktemp -d)
cat >"$run_dir/pgbouncer.ini" <<INI
[databases]
$DB_NAME = host=$DB_HOST port=$DB_PORT dbname=$DB_NAME user=$DB_USER password=$DB_PASSWORD

[pgbouncer]
listen_addr = 127.0.0.1
listen_port = 6432
unix_socket_dir =
auth_type = any
pool_mode = transaction
default_pool_size = $DB_POOL_SIZE
max_client_conn = $MAX_CONNECTIONS
server_connect_timeout = 5
query_wait_timeout = 10
log_connections = 0
log_disconnections = 0
INI
chmod 600 "$run_dir/pgbouncer.ini"

pgbouncer "$run_dir/pgbouncer.ini" &
pgbouncer_pid=$!

# handler.sh's psql connects through the pool.
export PGHOST=127.0.0.1 PGPORT=6432 PGDATABASE=$DB_NAME PGUSER=$DB_USER
export PGCLIENTENCODING=UTF8 PGCONNECT_TIMEOUT=5 PGAPPNAME=apibattle_api

for _ in $(seq 50); do
  psql -XqAtc 'SELECT 1' >/dev/null 2>&1 && break
  sleep 0.1
done
psql -XqAtc 'SELECT 1' >/dev/null || { echo '{"level":"ERROR","msg":"cannot reach database"}' >&2; exit 1; }

echo "{\"level\":\"INFO\",\"msg\":\"ApiBattle API listening\",\"addr\":\":$PORT\"}"
socat -T 15 \
  "TCP-LISTEN:$PORT,reuseaddr,fork,backlog=1024,max-children=$MAX_CONNECTIONS" \
  "EXEC:$(dirname "$0")/handler.sh" &
socat_pid=$!

trap 'kill -TERM "$socat_pid" "$pgbouncer_pid" 2>/dev/null' TERM INT
wait -n "$socat_pid" "$pgbouncer_pid"
status=$?
kill -TERM "$socat_pid" "$pgbouncer_pid" 2>/dev/null || true
wait
exit "$status"
