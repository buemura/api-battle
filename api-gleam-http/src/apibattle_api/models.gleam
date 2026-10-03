import gleam/dynamic/decode
import gleam/json.{type Json}
import gleam/option.{type Option, None, Some}
import gleam/string

pub type Account {
  Account(id: Int, name: String, balance: Int, created_at: String)
}

pub type TransactionType {
  Credit
  Debit
}

pub type Transaction {
  Transaction(
    id: Int,
    account_id: Int,
    kind: TransactionType,
    amount: Int,
    description: Option(String),
    created_at: String,
  )
}

pub type NewTransaction {
  NewTransaction(
    kind: TransactionType,
    amount: Int,
    description: Option(String),
  )
}

pub type Page(a) {
  Page(data: List(a), page: Int, page_size: Int, total: Int)
}

pub fn type_to_string(kind: TransactionType) -> String {
  case kind {
    Credit -> "credit"
    Debit -> "debit"
  }
}

// --- Row decoders (column order matches the SELECTs in `store`) -------------

pub fn account_decoder() -> decode.Decoder(Account) {
  use id <- decode.field(0, decode.int)
  use name <- decode.field(1, decode.string)
  use created_at <- decode.field(2, decode.string)
  use balance <- decode.field(3, decode.int)
  decode.success(Account(id:, name:, balance:, created_at:))
}

pub fn transaction_decoder() -> decode.Decoder(Transaction) {
  use id <- decode.field(0, decode.int)
  use account_id <- decode.field(1, decode.int)
  use kind <- decode.field(2, type_decoder())
  use amount <- decode.field(3, decode.int)
  use description <- decode.field(4, decode.optional(decode.string))
  use created_at <- decode.field(5, decode.string)
  decode.success(Transaction(
    id:,
    account_id:,
    kind:,
    amount:,
    description:,
    created_at:,
  ))
}

fn type_decoder() -> decode.Decoder(TransactionType) {
  use raw <- decode.then(decode.string)
  case raw {
    "credit" -> decode.success(Credit)
    "debit" -> decode.success(Debit)
    _ -> decode.failure(Credit, "TransactionType")
  }
}

// --- JSON encoders ----------------------------------------------------------

pub fn account_to_json(account: Account) -> Json {
  json.object([
    #("id", json.int(account.id)),
    #("name", json.string(account.name)),
    #("balance", json.int(account.balance)),
    #("created_at", json.string(account.created_at)),
  ])
}

pub fn transaction_to_json(transaction: Transaction) -> Json {
  json.object([
    #("id", json.int(transaction.id)),
    #("account_id", json.int(transaction.account_id)),
    #("type", json.string(type_to_string(transaction.kind))),
    #("amount", json.int(transaction.amount)),
    #("description", json.nullable(transaction.description, json.string)),
    #("created_at", json.string(transaction.created_at)),
  ])
}

pub fn page_to_json(page: Page(a), encode: fn(a) -> Json) -> Json {
  json.object([
    #("data", json.array(page.data, encode)),
    #("page", json.int(page.page)),
    #("page_size", json.int(page.page_size)),
    #("total", json.int(page.total)),
  ])
}

// --- Request validation -----------------------------------------------------

const max_description_length = 255

const max_bigint = 9_223_372_036_854_775_807

/// Validated field by field so each problem gets a specific message.
pub fn parse_new_transaction(
  body: decode.Dynamic,
) -> Result(NewTransaction, String) {
  let kind = case field(body, "type", decode.string) {
    Ok(Some("credit")) -> Ok(Credit)
    Ok(Some("debit")) -> Ok(Debit)
    _ -> Error("'type' must be either 'credit' or 'debit'")
  }

  let amount = case field(body, "amount", decode.int) {
    Ok(Some(amount)) if amount > 0 && amount <= max_bigint -> Ok(amount)
    _ -> Error("'amount' must be a positive integer (minor units, e.g. cents)")
  }

  let description = case field(body, "description", decode.string) {
    Ok(None) | Ok(Some("")) -> Ok(None)
    Ok(Some(text)) ->
      case string.length(text) <= max_description_length {
        True -> Ok(Some(text))
        False -> Error(description_error)
      }
    Error(_) -> Error(description_error)
  }

  case kind, amount, description {
    Ok(kind), Ok(amount), Ok(description) ->
      Ok(NewTransaction(kind:, amount:, description:))
    Error(msg), _, _ | _, Error(msg), _ | _, _, Error(msg) -> Error(msg)
  }
}

/// A missing key and an explicit `null` are both treated as absent.
fn field(
  body: decode.Dynamic,
  name: String,
  decoder: decode.Decoder(a),
) -> Result(Option(a), List(decode.DecodeError)) {
  decode.run(body, {
    use value <- decode.optional_field(name, None, decode.optional(decoder))
    decode.success(value)
  })
}

const description_error = "'description' must be a string of at most 255 characters"
