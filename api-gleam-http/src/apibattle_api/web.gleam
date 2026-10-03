import gleam/int
import gleam/json
import gleam/list
import gleam/result
import gleam/string
import pog
import wisp.{type Request, type Response}

pub type Context {
  Context(db: pog.Connection, openapi_spec: String)
}

/// Every non-2xx response is rendered as `{"error": "<message>"}`.
pub type ApiError {
  BadRequest(String)
  NotFound(String)
  Unprocessable(String)
  Internal(pog.QueryError)
}

pub fn error_response(error: ApiError) -> Response {
  let #(status, message) = case error {
    BadRequest(msg) -> #(400, msg)
    NotFound(msg) -> #(404, msg)
    Unprocessable(msg) -> #(422, msg)
    Internal(err) -> {
      wisp.log_error("database error: " <> string.inspect(err))
      #(500, "internal server error")
    }
  }
  json.object([#("error", json.string(message))])
  |> json.to_string
  |> wisp.json_response(status)
}

/// Unwraps a handler result into a response, rendering errors as JSON.
pub fn respond(result: Result(Response, ApiError)) -> Response {
  case result {
    Ok(response) -> response
    Error(error) -> error_response(error)
  }
}

// --- Path ids ---------------------------------------------------------------

const max_bigint = 9_223_372_036_854_775_807

/// A numeric path id. Non-numeric ids can never match a resource, so they are
/// reported as 404 rather than 400.
pub fn parse_id(raw: String) -> Result(Int, ApiError) {
  case int.parse(raw) {
    Ok(id) if id >= 0 && id <= max_bigint -> Ok(id)
    _ -> Error(NotFound("not found"))
  }
}

// --- Pagination -------------------------------------------------------------

const default_page_size = 20

const max_page_size = 100

pub type Pagination {
  Pagination(page: Int, page_size: Int)
}

pub fn limit(pagination: Pagination) -> Int {
  pagination.page_size
}

pub fn offset(pagination: Pagination) -> Int {
  { pagination.page - 1 } * pagination.page_size
}

pub fn pagination(request: Request) -> Result(Pagination, ApiError) {
  let query = wisp.get_query(request)
  let invalid =
    BadRequest("'page' must be >= 1 and 'page_size' must be between 1 and 100")

  use page <- result.try(
    parse_positive(list.key_find(query, "page"), 1)
    |> result.replace_error(invalid),
  )
  use page_size <- result.try(
    parse_positive(list.key_find(query, "page_size"), default_page_size)
    |> result.try(fn(size) {
      case size <= max_page_size {
        True -> Ok(size)
        False -> Error(Nil)
      }
    })
    |> result.replace_error(invalid),
  )
  Ok(Pagination(page:, page_size:))
}

/// Missing or empty values fall back to the default. The upper bound on `page`
/// keeps the computed OFFSET within a Postgres BIGINT.
fn parse_positive(raw: Result(String, Nil), fallback: Int) -> Result(Int, Nil) {
  case raw {
    Error(Nil) | Ok("") -> Ok(fallback)
    Ok(value) ->
      case int.parse(value) {
        Ok(n) if n >= 1 && n <= 4_294_967_295 -> Ok(n)
        _ -> Error(Nil)
      }
  }
}
