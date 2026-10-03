# ApiBattle

Simple API for banking API that allows managing accounts and transactions. It works as a ledger for tracking all financial activities, so transactions can only be added and not modified or deleted. And an account balance is always derived from the transactions.

## Features

- Get account details including current balance
- Get account transaction history
  - List transactions paginated sorted by latest first
- Get transaction details by ID
- Add new transactions

## Infra

- PostgreSQL
- Docker
- Nginx

## Testing

- K6 for load testing

## Running

```sh
docker compose up -d --build   # Postgres + 2 API replicas behind Nginx on :9999
# pick an implementation with API_IMPL (default: api-cpp-drogon)
API_IMPL=api-rust-axum docker compose up -d --build
docker run --rm -i --network apibattle_default -e BASE_URL=http://nginx \
  -v "$PWD/k6:/scripts" grafana/k6 run /scripts/load-test.js
```

## API

Accounts `1000` and `2000` are seeded by [db/init.sql](db/init.sql). Amounts are integers in minor units (e.g. cents). Balance = credits − debits; debits that would overdraw the account are rejected with `422`.

| Method | Path | Description |
|---|---|---|
| `GET` | `/accounts?page=1&page_size=20` | List accounts with balances, ordered by ID (`page_size` ≤ 100) |
| `GET` | `/accounts/{id}` | Account details with current balance |
| `GET` | `/accounts/{id}/transactions?page=1&page_size=20` | Transaction history, latest first (`page_size` ≤ 100) |
| `POST` | `/accounts/{id}/transactions` | Add a transaction — `{"type": "credit"\|"debit", "amount": 1000, "description": "optional"}` |
| `GET` | `/transactions/{id}` | Transaction details |
| `GET` | `/health` | Health check |
| `GET` | `/docs` | Swagger UI |
| `GET` | `/openapi.yaml` | OpenAPI 3 spec |

## Implementations

- [api-cpp-drogon](api-cpp-drogon/) — C++20, [Drogon](https://github.com/drogonframework/drogon) HTTP framework with its async PostgreSQL client and coroutines
- [api-go-gin](api-go-gin/) — Go, [Gin](https://github.com/gin-gonic/gin) HTTP framework with [pgx](https://github.com/jackc/pgx) connection pool
- [api-rust-axum](api-rust-axum/) — Rust, [axum](https://github.com/tokio-rs/axum) on Tokio with [sqlx](https://github.com/launchbadge/sqlx) for async PostgreSQL access
- [api-python-fastapi](api-python-fastapi/) — Python 3.13, [FastAPI](https://fastapi.tiangolo.com/) on Uvicorn (uvloop + httptools) with async [SQLAlchemy 2.0](https://www.sqlalchemy.org/) ORM over asyncpg
- [api-python-robyn](api-python-robyn/) — Python 3.13, [Robyn](https://robyn.tech/) (Rust runtime) with async [SQLAlchemy 2.0](https://www.sqlalchemy.org/) ORM over asyncpg
- [api-bash-socat](api-bash-socat/) — Bash, [socat](http://www.dest-unreach.org/socat/) forking a handler per connection, [jq](https://jqlang.org/) for JSON and `psql` (parameterized via psql variables) through an in-container [PgBouncer](https://www.pgbouncer.org/) pool
- [api-gleam-http](api-gleam-http/) — Gleam on the BEAM, [Wisp](https://github.com/gleam-wisp/wisp) on the [Mist](https://github.com/rawhat/mist) HTTP server with the [pog](https://github.com/lpil/pog) PostgreSQL connection pool
- [api-cs-minimalapi](api-cs-minimalapi/) — C# / .NET 10, ASP.NET Core [Minimal APIs](https://learn.microsoft.com/aspnet/core/fundamentals/minimal-apis) with [EF Core](https://learn.microsoft.com/ef/core/) over [Npgsql](https://www.npgsql.org/efcore/) (pooled DbContext)
- [api-postgrest](api-postgrest/) — [PostgREST](https://postgrest.org/) serving PL/pgSQL functions (validation and ledger rules live in the database), with nginx in the same container mapping the REST paths onto `/rpc/*`
