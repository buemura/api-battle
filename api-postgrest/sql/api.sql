-- ApiBattle API exposed through PostgREST.
--
-- Applied by every replica on startup inside a single transaction. The `api`
-- schemas hold no data, so they are dropped and recreated from scratch; the
-- advisory lock serializes replicas that boot at the same time.
DO $$ BEGIN PERFORM pg_advisory_xact_lock(hashtext('apibattle.api-postgrest.migrate')); END $$;

-- Role PostgREST switches to for every (unauthenticated) request. It can only
-- execute the functions in the `api` schema; those run as their owner.
DO $$
BEGIN
    IF NOT EXISTS (SELECT FROM pg_roles WHERE rolname = 'web_anon') THEN
        CREATE ROLE web_anon NOLOGIN;
    END IF;
END $$;
GRANT web_anon TO CURRENT_USER;
ALTER ROLE web_anon SET statement_timeout = '10s';

DROP SCHEMA IF EXISTS api, api_private CASCADE;
CREATE SCHEMA api;          -- exposed by PostgREST
CREATE SCHEMA api_private;  -- helpers, not reachable over HTTP
REVOKE ALL ON SCHEMA api_private FROM PUBLIC;

------------------------------------------------------------------------------
-- Helpers
------------------------------------------------------------------------------

-- Sets the HTTP status PostgREST responds with and passes the body through.
CREATE OR REPLACE FUNCTION api_private.respond(status int, body json) RETURNS json
LANGUAGE plpgsql AS $$
BEGIN
    PERFORM set_config('response.status', status::text, true);
    RETURN body;
END $$;

-- Renders {"error": "<message>"} with the given status.
CREATE OR REPLACE FUNCTION api_private.error(status int, message text) RETURNS json
LANGUAGE sql AS $$
    SELECT api_private.respond(status, json_build_object('error', message))
$$;

-- Parses a path id; NULL when it is not a valid bigint. Non-numeric ids can
-- never match a resource, so callers report them as 404.
CREATE OR REPLACE FUNCTION api_private.parse_id(raw text) RETURNS bigint
LANGUAGE plpgsql IMMUTABLE AS $$
BEGIN
    -- Nested IFs: SQL doesn't guarantee OR short-circuits before the cast.
    IF raw IS NULL OR raw !~ '^[0-9]{1,19}$' THEN
        RETURN NULL;
    END IF;
    IF raw::numeric > 9223372036854775807 THEN
        RETURN NULL;
    END IF;
    RETURN raw::bigint;
END $$;

-- Parses a positive int query param; `fallback` when absent, NULL when invalid.
CREATE OR REPLACE FUNCTION api_private.parse_positive(raw text, fallback int) RETURNS int
LANGUAGE plpgsql IMMUTABLE AS $$
BEGIN
    IF raw IS NULL OR raw = '' THEN
        RETURN fallback;
    END IF;
    IF raw !~ '^\+?[0-9]{1,10}$' THEN
        RETURN NULL;
    END IF;
    IF raw::bigint NOT BETWEEN 1 AND 2147483647 THEN
        RETURN NULL;
    END IF;
    RETURN raw::int;
END $$;

-- ISO-8601 UTC with millisecond precision, e.g. "2026-10-03T02:44:35.274Z".
CREATE OR REPLACE FUNCTION api_private.iso8601(ts timestamptz) RETURNS text
LANGUAGE sql STABLE AS $$
    SELECT to_char(ts AT TIME ZONE 'UTC', 'YYYY-MM-DD"T"HH24:MI:SS.MS"Z"')
$$;

CREATE OR REPLACE FUNCTION api_private.account_json(a public.accounts, balance bigint) RETURNS json
LANGUAGE sql STABLE AS $$
    SELECT json_build_object(
        'id', a.id,
        'name', a.name,
        'balance', balance,
        'created_at', api_private.iso8601(a.created_at))
$$;

CREATE OR REPLACE FUNCTION api_private.transaction_json(t public.transactions) RETURNS json
LANGUAGE sql STABLE AS $$
    SELECT json_build_object(
        'id', t.id,
        'account_id', t.account_id,
        'type', t.type,
        'amount', t.amount,
        'description', t.description,
        'created_at', api_private.iso8601(t.created_at))
$$;

-- Current balance derived from the ledger: credits minus debits.
CREATE OR REPLACE FUNCTION api_private.balance(account_id bigint) RETURNS bigint
LANGUAGE sql STABLE AS $$
    SELECT COALESCE(SUM(CASE WHEN t.type = 'credit' THEN t.amount ELSE -t.amount END), 0)::bigint
    FROM public.transactions t
    WHERE t.account_id = balance.account_id
$$;

------------------------------------------------------------------------------
-- Endpoints (nginx maps the public REST paths onto these /rpc/* calls)
------------------------------------------------------------------------------

-- PostgREST media type handler: functions returning this domain respond with
-- Content-Type: text/plain.
CREATE DOMAIN api."text/plain" AS text;

-- GET /health (round-trips to the database)
CREATE OR REPLACE FUNCTION api.health() RETURNS api."text/plain"
LANGUAGE sql STABLE AS $$
    SELECT 'ok'::api."text/plain"
$$;

-- GET /accounts?page&page_size
CREATE OR REPLACE FUNCTION api.list_accounts(page text DEFAULT NULL, page_size text DEFAULT NULL)
RETURNS json
LANGUAGE plpgsql STABLE SECURITY DEFINER SET search_path = public, pg_temp AS $$
DECLARE
    v_page      int := api_private.parse_positive(list_accounts.page, 1);
    v_page_size int := api_private.parse_positive(list_accounts.page_size, 20);
BEGIN
    IF v_page IS NULL OR v_page_size IS NULL OR v_page_size > 100 THEN
        RETURN api_private.error(400, '''page'' must be >= 1 and ''page_size'' must be between 1 and 100');
    END IF;

    RETURN json_build_object(
        'data', COALESCE((
            SELECT json_agg(api_private.account_json(a, api_private.balance(a.id)) ORDER BY a.id)
            FROM (
                SELECT * FROM accounts
                ORDER BY id
                LIMIT v_page_size OFFSET (v_page - 1)::bigint * v_page_size
            ) a), '[]'::json),
        'page', v_page,
        'page_size', v_page_size,
        'total', (SELECT count(*) FROM accounts));
END $$;

-- GET /accounts/{id}
CREATE OR REPLACE FUNCTION api.get_account(id text) RETURNS json
LANGUAGE plpgsql STABLE SECURITY DEFINER SET search_path = public, pg_temp AS $$
DECLARE
    v_id      bigint := api_private.parse_id(get_account.id);
    v_account accounts;
BEGIN
    IF v_id IS NULL THEN
        RETURN api_private.error(404, 'not found');
    END IF;

    SELECT * INTO v_account FROM accounts a WHERE a.id = v_id;
    IF NOT FOUND THEN
        RETURN api_private.error(404, 'account not found');
    END IF;
    RETURN api_private.account_json(v_account, api_private.balance(v_id));
END $$;

-- GET /accounts/{id}/transactions?page&page_size (latest first)
CREATE OR REPLACE FUNCTION api.list_transactions(id text, page text DEFAULT NULL, page_size text DEFAULT NULL)
RETURNS json
LANGUAGE plpgsql STABLE SECURITY DEFINER SET search_path = public, pg_temp AS $$
DECLARE
    v_id        bigint := api_private.parse_id(list_transactions.id);
    v_page      int := api_private.parse_positive(list_transactions.page, 1);
    v_page_size int := api_private.parse_positive(list_transactions.page_size, 20);
    v_total     bigint;
BEGIN
    IF v_id IS NULL THEN
        RETURN api_private.error(404, 'not found');
    END IF;
    IF v_page IS NULL OR v_page_size IS NULL OR v_page_size > 100 THEN
        RETURN api_private.error(400, '''page'' must be >= 1 and ''page_size'' must be between 1 and 100');
    END IF;

    SELECT (SELECT count(*) FROM transactions t WHERE t.account_id = a.id)
    INTO v_total
    FROM accounts a WHERE a.id = v_id;
    IF NOT FOUND THEN
        RETURN api_private.error(404, 'account not found');
    END IF;

    RETURN json_build_object(
        'data', COALESCE((
            SELECT json_agg(api_private.transaction_json(t) ORDER BY t.id DESC)
            FROM (
                SELECT * FROM transactions tx
                WHERE tx.account_id = v_id
                ORDER BY tx.id DESC
                LIMIT v_page_size OFFSET (v_page - 1)::bigint * v_page_size
            ) t), '[]'::json),
        'page', v_page,
        'page_size', v_page_size,
        'total', v_total);
END $$;

-- POST /accounts/{id}/transactions
--
-- nginx forwards the raw request body as text/plain (so malformed JSON gets
-- our own 400 instead of PostgREST's) and the account id in X-Account-Id.
CREATE OR REPLACE FUNCTION api.add_transaction(text) RETURNS json
LANGUAGE plpgsql VOLATILE SECURITY DEFINER SET search_path = public, pg_temp AS $$
DECLARE
    v_account_id  bigint := api_private.parse_id(
                              current_setting('request.headers', true)::json ->> 'x-account-id');
    v_body        json;
    v_type        text;
    v_amount      bigint;
    v_description json;
    v_tx          transactions;
BEGIN
    IF v_account_id IS NULL THEN
        RETURN api_private.error(404, 'not found');
    END IF;

    -- Validate field by field so each problem gets a specific message.
    IF $1 IS NULL OR NOT pg_input_is_valid($1, 'json') THEN
        RETURN api_private.error(400, 'request body must be JSON');
    END IF;
    v_body := $1::json;
    IF json_typeof(v_body) IS DISTINCT FROM 'object' THEN
        RETURN api_private.error(400, 'request body must be JSON');
    END IF;

    v_type := v_body ->> 'type';
    IF json_typeof(v_body -> 'type') IS DISTINCT FROM 'string' OR v_type NOT IN ('credit', 'debit') THEN
        RETURN api_private.error(400, '''type'' must be either ''credit'' or ''debit''');
    END IF;

    -- Compare the literal JSON text so floats like 10.5 or 1e3 are rejected
    -- rather than rounded.
    v_amount := api_private.parse_id(
                    CASE WHEN json_typeof(v_body -> 'amount') = 'number' THEN (v_body -> 'amount')::text END);
    IF v_amount IS NULL OR v_amount < 1 THEN
        RETURN api_private.error(400, '''amount'' must be a positive integer (minor units, e.g. cents)');
    END IF;

    v_description := v_body -> 'description';
    IF json_typeof(v_description) NOT IN ('null', 'string')
       OR char_length(v_body ->> 'description') > 255 THEN
        RETURN api_private.error(400, '''description'' must be a string of at most 255 characters');
    END IF;

    -- Lock the account row so concurrent debits can't overdraw it.
    PERFORM 1 FROM accounts a WHERE a.id = v_account_id FOR UPDATE;
    IF NOT FOUND THEN
        RETURN api_private.error(404, 'account not found');
    END IF;

    IF v_type = 'debit' AND api_private.balance(v_account_id) < v_amount THEN
        RETURN api_private.error(422, 'insufficient funds');
    END IF;

    INSERT INTO transactions (account_id, type, amount, description)
    VALUES (v_account_id, v_type, v_amount, NULLIF(v_body ->> 'description', ''))
    RETURNING * INTO v_tx;

    RETURN api_private.respond(201, api_private.transaction_json(v_tx));
END $$;

-- GET /transactions/{id}
CREATE OR REPLACE FUNCTION api.get_transaction(id text) RETURNS json
LANGUAGE plpgsql STABLE SECURITY DEFINER SET search_path = public, pg_temp AS $$
DECLARE
    v_id bigint := api_private.parse_id(get_transaction.id);
    v_tx transactions;
BEGIN
    IF v_id IS NULL THEN
        RETURN api_private.error(404, 'not found');
    END IF;

    SELECT * INTO v_tx FROM transactions t WHERE t.id = v_id;
    IF NOT FOUND THEN
        RETURN api_private.error(404, 'transaction not found');
    END IF;
    RETURN api_private.transaction_json(v_tx);
END $$;

------------------------------------------------------------------------------
-- Privileges
------------------------------------------------------------------------------

GRANT USAGE ON SCHEMA api TO web_anon;
REVOKE EXECUTE ON ALL FUNCTIONS IN SCHEMA api FROM PUBLIC;
GRANT EXECUTE ON ALL FUNCTIONS IN SCHEMA api TO web_anon;
