use chrono::{DateTime, SecondsFormat, Utc};
use serde::{Deserialize, Serialize, Serializer};

/// Renders timestamps as ISO-8601 UTC with millisecond precision,
/// e.g. `2026-10-03T02:44:35.274Z`.
fn iso_millis<S: Serializer>(ts: &DateTime<Utc>, s: S) -> Result<S::Ok, S::Error> {
    s.serialize_str(&ts.to_rfc3339_opts(SecondsFormat::Millis, true))
}

#[derive(Debug, Serialize, sqlx::FromRow)]
pub struct Account {
    pub id: i64,
    pub name: String,
    pub balance: i64,
    #[serde(serialize_with = "iso_millis")]
    pub created_at: DateTime<Utc>,
}

#[derive(Debug, Clone, Copy, PartialEq, Eq, Serialize, Deserialize, sqlx::Type)]
#[serde(rename_all = "lowercase")]
#[sqlx(type_name = "varchar", rename_all = "lowercase")]
pub enum TransactionType {
    Credit,
    Debit,
}

#[derive(Debug, Serialize, sqlx::FromRow)]
pub struct Transaction {
    pub id: i64,
    pub account_id: i64,
    #[serde(rename = "type")]
    #[sqlx(rename = "type")]
    pub kind: TransactionType,
    pub amount: i64,
    pub description: Option<String>,
    #[serde(serialize_with = "iso_millis")]
    pub created_at: DateTime<Utc>,
}

#[derive(Debug, Serialize)]
pub struct Page<T> {
    pub data: Vec<T>,
    pub page: u32,
    pub page_size: u32,
    pub total: i64,
}
