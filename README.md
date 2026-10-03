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
- [api-elixir-phoenix](api-elixir-phoenix/) — Elixir on the BEAM, [Phoenix](https://www.phoenixframework.org/) on the [Bandit](https://github.com/mtrudel/bandit) HTTP server with [Ecto](https://hexdocs.pm/ecto_sql/) over [Postgrex](https://github.com/elixir-ecto/postgrex)
- [api-cs-minimalapi](api-cs-minimalapi/) — C# / .NET 10, ASP.NET Core [Minimal APIs](https://learn.microsoft.com/aspnet/core/fundamentals/minimal-apis) with [EF Core](https://learn.microsoft.com/ef/core/) over [Npgsql](https://www.npgsql.org/efcore/) (pooled DbContext)
- [api-kotlin-ktor](api-kotlin-ktor/) — Kotlin, [Ktor](https://ktor.io/) on Netty with [Exposed](https://github.com/JetBrains/Exposed) over a [HikariCP](https://github.com/brettwooldridge/HikariCP) JDBC pool
- [api-postgrest](api-postgrest/) — [PostgREST](https://postgrest.org/) serving PL/pgSQL functions (validation and ledger rules live in the database), with nginx in the same container mapping the REST paths onto `/rpc/*`
- [api-node-express](api-node-express/) — Node.js 22 / TypeScript, [Express 5](https://expressjs.com/) with [Drizzle ORM](https://orm.drizzle.team/) over [node-postgres](https://node-postgres.com/), [zod](https://zod.dev/) validation and [pino](https://getpino.io/) logging
- [api-java-springboot](api-java-springboot/) — Java 25, [Spring Boot 4](https://spring.io/projects/spring-boot) Web MVC on Tomcat with virtual threads, [Spring Data JPA](https://spring.io/projects/spring-data-jpa) / Hibernate over a HikariCP pool
