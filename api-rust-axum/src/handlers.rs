use axum::{
    Json,
    extract::{FromRequestParts, Path, State, rejection::JsonRejection},
    http::{StatusCode, request::Parts},
};
use serde_json::Value;
use sqlx::PgPool;

use crate::{
    error::{ApiError, ApiResult},
    models::{Account, Page, Transaction, TransactionType},
    pagination::Pagination,
};

const MAX_DESCRIPTION_LENGTH: usize = 255;

/// Accounts with their balance derived from the ledger. Callers append a
/// WHERE and/or ORDER BY clause.
const ACCOUNT_SELECT: &str = "\
    SELECT a.id, a.name, a.created_at, COALESCE(b.balance, 0) AS balance \
    FROM accounts a LEFT JOIN LATERAL ( \
        SELECT SUM(CASE WHEN t.type = 'credit' THEN t.amount ELSE -t.amount END)::bigint AS balance \
        FROM transactions t WHERE t.account_id = a.id \
    ) b ON true";

const TRANSACTION_COLUMNS: &str = "id, account_id, type, amount, description, created_at";

/// A numeric path id. Non-numeric ids can never match a resource, so they are
/// reported as 404 rather than axum's plain-text 400.
pub struct Id(i64);

impl<S: Send + Sync> FromRequestParts<S> for Id {
    type Rejection = ApiError;

    async fn from_request_parts(parts: &mut Parts, state: &S) -> Result<Self, Self::Rejection> {
        Path::<i64>::from_request_parts(parts, state)
            .await
            .map(|Path(id)| Id(id))
            .map_err(|_| ApiError::NotFound("not found"))
    }
}

pub async fn health() -> &'static str {
    "ok"
}

pub async fn list_accounts(
    State(db): State<PgPool>,
    pagination: Pagination,
) -> ApiResult<Json<Page<Account>>> {
    let total: i64 = sqlx::query_scalar("SELECT count(*) FROM accounts")
        .fetch_one(&db)
        .await?;
    let data = sqlx::query_as::<_, Account>(&format!(
        "{ACCOUNT_SELECT} ORDER BY a.id LIMIT $1 OFFSET $2"
    ))
    .bind(pagination.limit())
    .bind(pagination.offset())
    .fetch_all(&db)
    .await?;

    Ok(Json(Page {
        data,
        page: pagination.page,
        page_size: pagination.page_size,
        total,
    }))
}

pub async fn get_account(State(db): State<PgPool>, Id(id): Id) -> ApiResult<Json<Account>> {
    sqlx::query_as::<_, Account>(&format!("{ACCOUNT_SELECT} WHERE a.id = $1"))
        .bind(id)
        .fetch_optional(&db)
        .await?
        .map(Json)
        .ok_or(ApiError::NotFound("account not found"))
}

pub async fn list_transactions(
    State(db): State<PgPool>,
    Id(id): Id,
    pagination: Pagination,
) -> ApiResult<Json<Page<Transaction>>> {
    let total: i64 = sqlx::query_scalar(
        "SELECT (SELECT count(*) FROM transactions WHERE account_id = a.id) \
         FROM accounts a WHERE a.id = $1",
    )
    .bind(id)
    .fetch_optional(&db)
    .await?
    .ok_or(ApiError::NotFound("account not found"))?;

    let data = sqlx::query_as::<_, Transaction>(&format!(
        "SELECT {TRANSACTION_COLUMNS} FROM transactions WHERE account_id = $1 \
         ORDER BY id DESC LIMIT $2 OFFSET $3"
    ))
    .bind(id)
    .bind(pagination.limit())
    .bind(pagination.offset())
    .fetch_all(&db)
    .await?;

    Ok(Json(Page {
        data,
        page: pagination.page,
        page_size: pagination.page_size,
        total,
    }))
}

pub struct NewTransaction {
    kind: TransactionType,
    amount: i64,
    description: Option<String>,
}

impl TryFrom<Value> for NewTransaction {
    type Error = ApiError;

    // Validated field by field so each problem gets a specific message.
    fn try_from(body: Value) -> Result<Self, Self::Error> {
        let bad = |msg: &str| ApiError::BadRequest(msg.to_owned());

        let kind = match body.get("type").and_then(Value::as_str) {
            Some("credit") => TransactionType::Credit,
            Some("debit") => TransactionType::Debit,
            _ => return Err(bad("'type' must be either 'credit' or 'debit'")),
        };

        let amount = body
            .get("amount")
            .and_then(Value::as_i64)
            .filter(|a| *a > 0)
            .ok_or_else(|| bad("'amount' must be a positive integer (minor units, e.g. cents)"))?;

        let description = match body.get("description") {
            None | Some(Value::Null) => None,
            Some(Value::String(s)) if s.chars().count() <= MAX_DESCRIPTION_LENGTH => {
                Some(s.clone()).filter(|s| !s.is_empty())
            }
            Some(_) => {
                return Err(bad(
                    "'description' must be a string of at most 255 characters",
                ));
            }
        };

        Ok(NewTransaction {
            kind,
            amount,
            description,
        })
    }
}

pub async fn add_transaction(
    State(db): State<PgPool>,
    Id(id): Id,
    body: Result<Json<Value>, JsonRejection>,
) -> ApiResult<(StatusCode, Json<Transaction>)> {
    let Json(body) =
        body.map_err(|_| ApiError::BadRequest("request body must be JSON".to_owned()))?;
    let new = NewTransaction::try_from(body)?;

    let mut tx = db.begin().await?;

    // Lock the account row so concurrent debits can't overdraw it.
    sqlx::query("SELECT id FROM accounts WHERE id = $1 FOR UPDATE")
        .bind(id)
        .fetch_optional(&mut *tx)
        .await?
        .ok_or(ApiError::NotFound("account not found"))?;

    if new.kind == TransactionType::Debit {
        let balance: i64 = sqlx::query_scalar(
            "SELECT COALESCE(SUM(CASE WHEN type = 'credit' THEN amount ELSE -amount END), 0)::bigint \
             FROM transactions WHERE account_id = $1",
        )
        .bind(id)
        .fetch_one(&mut *tx)
        .await?;
        if balance < new.amount {
            return Err(ApiError::Unprocessable("insufficient funds"));
        }
    }

    let created = sqlx::query_as::<_, Transaction>(&format!(
        "INSERT INTO transactions (account_id, type, amount, description) \
         VALUES ($1, $2, $3, $4) RETURNING {TRANSACTION_COLUMNS}"
    ))
    .bind(id)
    .bind(new.kind)
    .bind(new.amount)
    .bind(new.description)
    .fetch_one(&mut *tx)
    .await?;

    tx.commit().await?;
    Ok((StatusCode::CREATED, Json(created)))
}

pub async fn get_transaction(State(db): State<PgPool>, Id(id): Id) -> ApiResult<Json<Transaction>> {
    sqlx::query_as::<_, Transaction>(&format!(
        "SELECT {TRANSACTION_COLUMNS} FROM transactions WHERE id = $1"
    ))
    .bind(id)
    .fetch_optional(&db)
    .await?
    .map(Json)
    .ok_or(ApiError::NotFound("transaction not found"))
}
