//// SQL access. Balances are always derived from the ledger.

import gleam/dynamic/decode
import gleam/option.{type Option}
import gleam/result
import apibattle_api/models.{
  type Account, type NewTransaction, type Transaction, Debit,
}
import apibattle_api/web.{type ApiError, type Pagination, Internal, NotFound}
import pog

/// ISO-8601 UTC with millisecond precision, e.g. `2026-10-03T02:44:35.274Z`.
const iso_millis = "to_char(created_at AT TIME ZONE 'UTC', 'YYYY-MM-DD\"T\"HH24:MI:SS.MS\"Z\"')"

/// Accounts with their balance derived from the ledger. Callers append a
/// WHERE and/or ORDER BY clause.
const account_select = "
  SELECT a.id, a.name,
    to_char(a.created_at AT TIME ZONE 'UTC', 'YYYY-MM-DD\"T\"HH24:MI:SS.MS\"Z\"'),
    COALESCE(b.balance, 0)
  FROM accounts a LEFT JOIN LATERAL (
    SELECT SUM(CASE WHEN t.type = 'credit' THEN t.amount ELSE -t.amount END)::bigint AS balance
    FROM transactions t WHERE t.account_id = a.id
  ) b ON true"

const transaction_columns = "id, account_id, type, amount, description, "
  <> iso_millis

pub fn count_accounts(db: pog.Connection) -> Result(Int, ApiError) {
  pog.query("SELECT count(*) FROM accounts")
  |> pog.returning(decode.at([0], decode.int))
  |> one(db)
}

pub fn list_accounts(
  db: pog.Connection,
  pagination: Pagination,
) -> Result(List(Account), ApiError) {
  pog.query(account_select <> " ORDER BY a.id LIMIT $1 OFFSET $2")
  |> pog.parameter(pog.int(web.limit(pagination)))
  |> pog.parameter(pog.int(web.offset(pagination)))
  |> pog.returning(models.account_decoder())
  |> all(db)
}

pub fn get_account(db: pog.Connection, id: Int) -> Result(Account, ApiError) {
  pog.query(account_select <> " WHERE a.id = $1")
  |> pog.parameter(pog.int(id))
  |> pog.returning(models.account_decoder())
  |> optional(db)
  |> result.try(found("account not found"))
}

/// Number of transactions on an account, or NotFound if the account is missing.
pub fn count_transactions(
  db: pog.Connection,
  account_id: Int,
) -> Result(Int, ApiError) {
  pog.query(
    "SELECT (SELECT count(*) FROM transactions WHERE account_id = a.id)
     FROM accounts a WHERE a.id = $1",
  )
  |> pog.parameter(pog.int(account_id))
  |> pog.returning(decode.at([0], decode.int))
  |> optional(db)
  |> result.try(found("account not found"))
}

pub fn list_transactions(
  db: pog.Connection,
  account_id: Int,
  pagination: Pagination,
) -> Result(List(Transaction), ApiError) {
  pog.query("SELECT " <> transaction_columns <> " FROM transactions
     WHERE account_id = $1 ORDER BY id DESC LIMIT $2 OFFSET $3")
  |> pog.parameter(pog.int(account_id))
  |> pog.parameter(pog.int(web.limit(pagination)))
  |> pog.parameter(pog.int(web.offset(pagination)))
  |> pog.returning(models.transaction_decoder())
  |> all(db)
}

pub fn get_transaction(
  db: pog.Connection,
  id: Int,
) -> Result(Transaction, ApiError) {
  pog.query(
    "SELECT " <> transaction_columns <> " FROM transactions WHERE id = $1",
  )
  |> pog.parameter(pog.int(id))
  |> pog.returning(models.transaction_decoder())
  |> optional(db)
  |> result.try(found("transaction not found"))
}

pub fn add_transaction(
  db: pog.Connection,
  account_id: Int,
  new: NewTransaction,
) -> Result(Transaction, ApiError) {
  pog.transaction(db, fn(tx) {
    // Lock the account row so concurrent debits can't overdraw it.
    use _ <- result.try(
      pog.query("SELECT id FROM accounts WHERE id = $1 FOR UPDATE")
      |> pog.parameter(pog.int(account_id))
      |> optional(tx)
      |> result.try(found("account not found")),
    )

    use _ <- result.try(case new.kind {
      Debit -> {
        use balance <- result.try(balance(tx, account_id))
        case balance < new.amount {
          True -> Error(web.Unprocessable("insufficient funds"))
          False -> Ok(Nil)
        }
      }
      _ -> Ok(Nil)
    })

    pog.query("INSERT INTO transactions (account_id, type, amount, description)
       VALUES ($1, $2, $3, $4) RETURNING " <> transaction_columns)
    |> pog.parameter(pog.int(account_id))
    |> pog.parameter(pog.text(models.type_to_string(new.kind)))
    |> pog.parameter(pog.int(new.amount))
    |> pog.parameter(pog.nullable(pog.text, new.description))
    |> pog.returning(models.transaction_decoder())
    |> one(tx)
  })
  |> result.map_error(fn(error) {
    case error {
      pog.TransactionRolledBack(error) -> error
      pog.TransactionQueryError(error) -> Internal(error)
    }
  })
}

fn balance(db: pog.Connection, account_id: Int) -> Result(Int, ApiError) {
  pog.query(
    "SELECT COALESCE(SUM(CASE WHEN type = 'credit' THEN amount ELSE -amount END), 0)::bigint
     FROM transactions WHERE account_id = $1",
  )
  |> pog.parameter(pog.int(account_id))
  |> pog.returning(decode.at([0], decode.int))
  |> one(db)
}

// --- Helpers ----------------------------------------------------------------

fn all(query: pog.Query(a), db: pog.Connection) -> Result(List(a), ApiError) {
  pog.execute(query, db)
  |> result.map(fn(returned) { returned.rows })
  |> result.map_error(Internal)
}

fn optional(
  query: pog.Query(a),
  db: pog.Connection,
) -> Result(Option(a), ApiError) {
  use rows <- result.map(all(query, db))
  case rows {
    [row, ..] -> option.Some(row)
    [] -> option.None
  }
}

fn one(query: pog.Query(a), db: pog.Connection) -> Result(a, ApiError) {
  use row <- result.try(optional(query, db))
  option.to_result(row, Internal(pog.UnexpectedResultType([])))
}

fn found(message: String) -> fn(Option(a)) -> Result(a, ApiError) {
  fn(row) { option.to_result(row, NotFound(message)) }
}
