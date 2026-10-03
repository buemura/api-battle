#!/usr/bin/env bash
# Handles one HTTP/1.1 request per connection. socat forks this script for
# every accepted connection, with the client socket on stdin/stdout.
#
# - jq parses and validates request JSON.
# - PostgreSQL renders every response body with json_build_object, so no JSON
#   is assembled by hand here.
# - User input only reaches SQL as psql variables interpolated with :'name',
#   which psql quotes as a safe literal.
set -uo pipefail
export LC_ALL=C # byte semantics for Content-Length and `read -N`

readonly MAX_BODY_BYTES=65536
readonly MAX_HEADERS=100
readonly HEADER_TIMEOUT=5
readonly DEFAULT_PAGE_SIZE=20
readonly MAX_PAGE_SIZE=100
readonly APP_DIR="${APP_DIR:-$(dirname "$0")}"

# ---------------------------------------------------------------- HTTP layer

reason() {
  case $1 in
    200) echo OK ;; 201) echo Created ;; 400) echo 'Bad Request' ;;
    404) echo 'Not Found' ;; 405) echo 'Method Not Allowed' ;;
    408) echo 'Request Timeout' ;; 413) echo 'Payload Too Large' ;;
    422) echo 'Unprocessable Entity' ;; *) echo 'Internal Server Error' ;;
  esac
}

# respond STATUS CONTENT_TYPE BODY
respond() {
  printf 'HTTP/1.1 %s %s\r\nContent-Type: %s\r\nContent-Length: %d\r\nConnection: close\r\n\r\n%s' \
    "$1" "$(reason "$1")" "$2" "${#3}" "$3"
  exit 0
}

respond_json() { respond "$1" 'application/json; charset=utf-8' "$2"; }

# respond_error STATUS MESSAGE — renders {"error": MESSAGE}
respond_error() { respond_json "$1" "$(jq -cn --arg m "$2" '{error: $m}')"; }

log_error() {
  jq -cn --arg msg "$1" --arg method "${method:-}" --arg path "${path:-}" --arg detail "${2:-}" \
    '{time: (now | todate), level: "ERROR", msg: $msg, method: $method, path: $path, detail: $detail}' >&2
}

# Reads the request line, headers and body into globals.
read_request() {
  local line name value i=0
  IFS=' ' read -r -t "$HEADER_TIMEOUT" method target _ || exit 0 # client went away
  target=${target%$'\r'}
  path=${target%%\?*}
  query=''
  [[ $target == *\?* ]] && query=${target#*\?}

  content_length=0
  while IFS= read -r -t "$HEADER_TIMEOUT" line; do
    line=${line%$'\r'}
    [[ -z $line ]] && break
    (( ++i > MAX_HEADERS )) && respond_error 400 'too many headers'
    name=${line%%:*}
    value=${line#*:}
    value=${value#"${value%%[![:space:]]*}"}
    if [[ ${name,,} == content-length ]]; then
      [[ $value =~ ^[0-9]{1,9}$ ]] || respond_error 400 'invalid Content-Length'
      content_length=$((10#$value))
    fi
  done || respond_error 408 'request timeout'

  (( content_length > MAX_BODY_BYTES )) && respond_error 413 'request body too large'
  body=''
  if (( content_length > 0 )); then
    IFS= read -r -d '' -N "$content_length" -t "$HEADER_TIMEOUT" body || respond_error 408 'request timeout'
  fi
}

# query_param NAME — prints the first value of NAME in the query string, URL-decoded.
query_param() {
  local pair key value
  local IFS='&'
  for pair in $query; do
    key=${pair%%=*}
    [[ $key == "$1" ]] || continue
    value=''
    [[ $pair == *=* ]] && value=${pair#*=}
    value=${value//+/ }
    printf '%b' "${value//%/\\x}"
    return
  done
}

# ------------------------------------------------------------- validation

# Sets `id` from a numeric path segment. Non-numeric or out-of-range ids can
# never match a resource, so they are reported as 404.
parse_id() {
  [[ $1 =~ ^[0-9]{1,19}$ ]] || respond_error 404 'not found'
  [[ ${#1} -lt 19 || $1 < 9223372036854775808 ]] || respond_error 404 'not found'
  id=$((10#$1))
}

# Sets `page`, `page_size` and `offset` from the query string.
parse_pagination() {
  local invalid="'page' must be >= 1 and 'page_size' must be between 1 and $MAX_PAGE_SIZE"
  page=$(query_param page)
  page_size=$(query_param page_size)
  page=${page:-1}
  page_size=${page_size:-$DEFAULT_PAGE_SIZE}
  [[ $page =~ ^[0-9]{1,10}$ && $page_size =~ ^[0-9]{1,10}$ ]] || respond_error 400 "$invalid"
  page=$((10#$page))
  page_size=$((10#$page_size))
  (( page >= 1 && page <= 2147483647 && page_size >= 1 && page_size <= MAX_PAGE_SIZE )) ||
    respond_error 400 "$invalid"
  offset=$(( (page - 1) * page_size ))
}

# Validates the POST body field by field so each problem gets a specific
# message. Sets `payload` to normalized JSON: {type, amount (string), description}.
parse_new_transaction() {
  local out
  # jq keeps number literals verbatim, so `amount` is checked exactly as an
  # int64: 10.5, 10.0 and 1e3 are all rejected rather than coerced.
  out=$(jq -rn '
    def fail($m): "ERR\t" + $m;
    [inputs] as $docs
    | if ($docs | length) != 1 or ($docs[0] | type) != "object" then fail("request body must be JSON")
      else $docs[0] as $b
      | ($b.amount | if type == "number" then tojson else "" end) as $amount
      | if ($b.type | IN("credit", "debit") | not) then
          fail("'"'"'type'"'"' must be either '"'"'credit'"'"' or '"'"'debit'"'"'")
        elif ($amount | test("^[1-9][0-9]{0,18}$") | not)
             or (($amount | length) == 19 and $amount > "9223372036854775807") then
          fail("'"'"'amount'"'"' must be a positive integer (minor units, e.g. cents)")
        elif ($b.description != null and (($b.description | type) != "string" or ($b.description | length) > 255)) then
          fail("'"'"'description'"'"' must be a string of at most 255 characters")
        else "OK\t" + ({type: $b.type, amount: $amount,
                        description: (if ($b.description // "") == "" then null else $b.description end)} | tojson)
        end
      end' <<<"$body" 2>/dev/null) || out=''
  case $out in
    OK$'\t'*) payload=${out#OK$'\t'} ;;
    ERR$'\t'*) respond_error 400 "${out#ERR$'\t'}" ;;
    *) respond_error 400 'request body must be JSON' ;;
  esac
}

# --------------------------------------------------------------- database

# SQL fragments rendering rows as JSON. Constants only; never user input.
readonly TS="'YYYY-MM-DD\"T\"HH24:MI:SS.MS\"Z\"'"
readonly ACCOUNT_JSON="json_build_object('id', a.id, 'name', a.name, 'balance', COALESCE(b.balance, 0),
  'created_at', to_char(a.created_at AT TIME ZONE 'UTC', $TS))"
readonly ACCOUNT_FROM="accounts a LEFT JOIN LATERAL (
  SELECT SUM(CASE WHEN t.type = 'credit' THEN t.amount ELSE -t.amount END)::bigint AS balance
  FROM transactions t WHERE t.account_id = a.id) b ON true"
readonly TRANSACTION_JSON="json_build_object('id', t.id, 'account_id', t.account_id, 'type', t.type,
  'amount', t.amount, 'description', t.description,
  'created_at', to_char(t.created_at AT TIME ZONE 'UTC', $TS))"

# sql [-v name=value ...] — runs SQL from stdin. Every query here returns a
# single row of (status, json_body); this responds with it and exits.
sql() {
  local out err json
  err=$(mktemp)
  if out=$(psql -X -q -A -t -F $'\t' -v ON_ERROR_STOP=1 "$@" 2>"$err"); then
    rm -f "$err"
    # Postgres pretty-prints json values; compact them (jq keeps key order).
    if [[ $out == [0-9][0-9][0-9]$'\t'* ]] && json=$(jq -c . <<<"${out#*$'\t'}" 2>/dev/null); then
      respond_json "${out%%$'\t'*}" "$json"
    fi
    log_error 'unexpected query result' "$out"
  else
    log_error 'query failed' "$(<"$err")"
    rm -f "$err"
  fi
  respond_error 500 'internal server error'
}

# ---------------------------------------------------------------- handlers

list_accounts() {
  parse_pagination
  sql -v limit="$page_size" -v offset="$offset" -v page="$page" <<SQL
SELECT 200, json_build_object(
  'data', COALESCE((SELECT json_agg(j ORDER BY id) FROM (
    SELECT a.id, $ACCOUNT_JSON AS j FROM $ACCOUNT_FROM
    ORDER BY a.id LIMIT :'limit' OFFSET :'offset') p), '[]'::json),
  'page', :'page'::int, 'page_size', :'limit'::int,
  'total', (SELECT count(*) FROM accounts));
SQL
}

get_account() {
  parse_id "$1"
  sql -v id="$id" <<SQL
SELECT 200, $ACCOUNT_JSON FROM $ACCOUNT_FROM WHERE a.id = :'id'
UNION ALL
SELECT 404, '{"error":"account not found"}'::json
WHERE NOT EXISTS (SELECT 1 FROM accounts WHERE id = :'id');
SQL
}

list_transactions() {
  parse_id "$1"
  parse_pagination
  sql -v id="$id" -v limit="$page_size" -v offset="$offset" -v page="$page" <<SQL
SELECT CASE WHEN found THEN 200 ELSE 404 END,
  CASE WHEN NOT found THEN '{"error":"account not found"}'::json
  ELSE json_build_object(
    'data', COALESCE((SELECT json_agg(j ORDER BY id DESC) FROM (
      SELECT t.id, $TRANSACTION_JSON AS j FROM transactions t
      WHERE t.account_id = :'id' ORDER BY t.id DESC LIMIT :'limit' OFFSET :'offset') p), '[]'::json),
    'page', :'page'::int, 'page_size', :'limit'::int,
    'total', (SELECT count(*) FROM transactions WHERE account_id = :'id'))
  END
FROM (SELECT EXISTS (SELECT 1 FROM accounts WHERE id = :'id') AS found) f;
SQL
}

add_transaction() {
  parse_id "$1"
  parse_new_transaction
  # Lock the account row first so concurrent debits can't overdraw it. The
  # insert runs as a separate statement so its snapshot (and therefore the
  # balance check) sees everything committed before the lock was granted.
  sql -v id="$id" -v payload="$payload" <<SQL
BEGIN;
SELECT 1 FROM accounts WHERE id = :'id' FOR UPDATE \g /dev/null
WITH input AS (
  SELECT p->>'type' AS type, (p->>'amount')::bigint AS amount, p->>'description' AS description
  FROM (SELECT :'payload'::jsonb AS p) x
), account AS (
  SELECT id FROM accounts WHERE id = :'id'
), balance AS (
  SELECT COALESCE(SUM(CASE WHEN type = 'credit' THEN amount ELSE -amount END), 0)::bigint AS value
  FROM transactions WHERE account_id = :'id'
), t AS (
  INSERT INTO transactions (account_id, type, amount, description)
  SELECT account.id, input.type, input.amount, input.description
  FROM account, input, balance
  WHERE input.type = 'credit' OR balance.value >= input.amount
  RETURNING *
)
SELECT 201, $TRANSACTION_JSON FROM t
UNION ALL
SELECT 404, '{"error":"account not found"}'::json WHERE NOT EXISTS (SELECT 1 FROM account)
UNION ALL
SELECT 422, '{"error":"insufficient funds"}'::json
WHERE EXISTS (SELECT 1 FROM account) AND NOT EXISTS (SELECT 1 FROM t);
COMMIT;
SQL
}

get_transaction() {
  parse_id "$1"
  sql -v id="$id" <<SQL
SELECT 200, $TRANSACTION_JSON FROM transactions t WHERE t.id = :'id'
UNION ALL
SELECT 404, '{"error":"transaction not found"}'::json
WHERE NOT EXISTS (SELECT 1 FROM transactions WHERE id = :'id');
SQL
}

# ------------------------------------------------------------------ router

# route ALLOWED_METHOD — 405 when the path matched but the method didn't.
route() { [[ $method == "$1" ]] || respond_error 405 'method not allowed'; }

read_request
case $path in
  /health) route GET; respond 200 'text/plain; charset=utf-8' 'ok' ;;
  /accounts) route GET; list_accounts ;;
  /accounts/*/transactions)
    seg=${path#/accounts/}; seg=${seg%/transactions}
    [[ $seg == */* ]] && respond_error 404 'not found'
    case $method in
      GET) list_transactions "$seg" ;;
      POST) add_transaction "$seg" ;;
      *) respond_error 405 'method not allowed' ;;
    esac ;;
  /accounts/*)
    seg=${path#/accounts/}
    [[ $seg == */* ]] && respond_error 404 'not found'
    route GET; get_account "$seg" ;;
  /transactions/*)
    seg=${path#/transactions/}
    [[ $seg == */* ]] && respond_error 404 'not found'
    route GET; get_transaction "$seg" ;;
  /openapi.yaml) route GET; respond 200 'application/yaml' "$(<"$APP_DIR/openapi.yaml")" ;;
  /docs) route GET; respond 200 'text/html; charset=utf-8' "$(<"$APP_DIR/docs.html")" ;;
  *) respond_error 404 'not found' ;;
esac
