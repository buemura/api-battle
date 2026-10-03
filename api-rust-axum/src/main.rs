mod docs;
mod error;
mod handlers;
mod models;
mod pagination;

use std::{env, net::SocketAddr, time::Duration};

use axum::{Router, http::StatusCode, routing::get};
use sqlx::postgres::{PgConnectOptions, PgPoolOptions};
use tokio::{net::TcpListener, signal};
use tower_http::{timeout::TimeoutLayer, trace::TraceLayer};
use tracing_subscriber::EnvFilter;

fn env_or(key: &str, fallback: &str) -> String {
    env::var(key)
        .ok()
        .filter(|v| !v.is_empty())
        .unwrap_or_else(|| fallback.to_owned())
}

fn env_parse<T: std::str::FromStr>(key: &str, fallback: T) -> T {
    env::var(key)
        .ok()
        .and_then(|v| v.parse().ok())
        .unwrap_or(fallback)
}

pub fn router(db: sqlx::PgPool) -> Router {
    Router::new()
        .route("/health", get(handlers::health))
        .route("/accounts", get(handlers::list_accounts))
        .route("/accounts/{id}", get(handlers::get_account))
        .route(
            "/accounts/{id}/transactions",
            get(handlers::list_transactions).post(handlers::add_transaction),
        )
        .route("/transactions/{id}", get(handlers::get_transaction))
        .route("/docs", get(docs::swagger_ui))
        .route("/openapi.yaml", get(docs::spec))
        .layer(TraceLayer::new_for_http())
        .layer(TimeoutLayer::with_status_code(
            StatusCode::REQUEST_TIMEOUT,
            Duration::from_secs(10),
        ))
        .with_state(db)
}

#[tokio::main]
async fn main() -> Result<(), Box<dyn std::error::Error>> {
    tracing_subscriber::fmt()
        .with_env_filter(
            EnvFilter::try_from_default_env().unwrap_or_else(|_| EnvFilter::new("info")),
        )
        .init();

    let connect = PgConnectOptions::new()
        .host(&env_or("DB_HOST", "localhost"))
        .port(env_parse("DB_PORT", 5432))
        .database(&env_or("DB_NAME", "apibattle"))
        .username(&env_or("DB_USER", "apibattle"))
        .password(&env_or("DB_PASSWORD", "apibattle"));

    let db = PgPoolOptions::new()
        .max_connections(env_parse("DB_POOL_SIZE", 10))
        .acquire_timeout(Duration::from_secs(5))
        .connect_with(connect)
        .await?;

    let addr = SocketAddr::from(([0, 0, 0, 0], env_parse("PORT", 8080)));
    let listener = TcpListener::bind(addr).await?;
    tracing::info!("ApiBattle API listening on {addr}");

    axum::serve(listener, router(db))
        .with_graceful_shutdown(shutdown_signal())
        .await?;
    Ok(())
}

async fn shutdown_signal() {
    let ctrl_c = async { signal::ctrl_c().await.expect("failed to listen for ctrl-c") };
    #[cfg(unix)]
    let terminate = async {
        signal::unix::signal(signal::unix::SignalKind::terminate())
            .expect("failed to listen for SIGTERM")
            .recv()
            .await;
    };
    #[cfg(not(unix))]
    let terminate = std::future::pending::<()>();

    tokio::select! {
        _ = ctrl_c => {},
        _ = terminate => {},
    }
    tracing::info!("shutting down");
}
