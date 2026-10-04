#!/bin/sh
set -e

# Octane warms the encrypter at boot, which requires a key. The API is
# stateless (no sessions, cookies or encrypted data), so an ephemeral key
# is fine when none is provided.
if [ -z "$APP_KEY" ]; then
  APP_KEY="base64:$(head -c 32 /dev/urandom | base64)"
  export APP_KEY
fi

# Cache config/routes/events against the runtime environment.
php artisan optimize --quiet

# PHP workers are synchronous and each keeps one persistent DB connection,
# so the worker count doubles as the connection pool size.
exec php artisan octane:frankenphp \
  --host=0.0.0.0 \
  --port="${PORT:-8080}" \
  --workers="${OCTANE_WORKERS:-${DB_POOL_SIZE:-10}}" \
  --max-requests="${OCTANE_MAX_REQUESTS:-10000}" \
  --log-level=warn
