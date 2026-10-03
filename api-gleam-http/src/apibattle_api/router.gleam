import gleam/dynamic/decode
import gleam/http.{Get, Post}
import gleam/json
import gleam/result
import apibattle_api/models.{Page}
import apibattle_api/store
import apibattle_api/web.{type Context, BadRequest, NotFound}
import wisp.{type Request, type Response}

/// Request bodies are tiny JSON documents; anything larger is rejected.
const max_body_size = 16_384

pub fn handle_request(request: Request, ctx: Context) -> Response {
  use <- wisp.rescue_crashes
  use request <- wisp.handle_head(request)
  let request = wisp.set_max_body_size(request, max_body_size)

  case wisp.path_segments(request) {
    ["health"] ->
      only(request, Get, fn() { wisp.ok() |> wisp.string_body("ok") })
    ["accounts"] -> only(request, Get, fn() { list_accounts(request, ctx) })
    ["accounts", id] -> only(request, Get, fn() { get_account(ctx, id) })
    ["accounts", id, "transactions"] ->
      case request.method {
        Get -> list_transactions(request, ctx, id)
        Post -> add_transaction(request, ctx, id)
        _ -> wisp.method_not_allowed([Get, Post])
      }
    ["transactions", id] ->
      only(request, Get, fn() { get_transaction(ctx, id) })
    ["docs"] -> only(request, Get, fn() { wisp.html_response(swagger_ui, 200) })
    ["openapi.yaml"] ->
      only(request, Get, fn() {
        wisp.ok()
        |> wisp.set_header("content-type", "application/yaml")
        |> wisp.string_body(ctx.openapi_spec)
      })
    _ -> web.error_response(NotFound("not found"))
  }
}

fn only(request: Request, method: http.Method, next: fn() -> Response) {
  case request.method == method {
    True -> next()
    False -> wisp.method_not_allowed([method])
  }
}

fn list_accounts(request: Request, ctx: Context) -> Response {
  web.respond({
    use pagination <- result.try(web.pagination(request))
    use total <- result.try(store.count_accounts(ctx.db))
    use data <- result.map(store.list_accounts(ctx.db, pagination))
    Page(data:, page: pagination.page, page_size: pagination.page_size, total:)
    |> models.page_to_json(models.account_to_json)
    |> json_ok(200)
  })
}

fn get_account(ctx: Context, raw_id: String) -> Response {
  web.respond({
    use id <- result.try(web.parse_id(raw_id))
    use account <- result.map(store.get_account(ctx.db, id))
    account |> models.account_to_json |> json_ok(200)
  })
}

fn list_transactions(request: Request, ctx: Context, raw_id: String) -> Response {
  web.respond({
    use id <- result.try(web.parse_id(raw_id))
    use pagination <- result.try(web.pagination(request))
    use total <- result.try(store.count_transactions(ctx.db, id))
    use data <- result.map(store.list_transactions(ctx.db, id, pagination))
    Page(data:, page: pagination.page, page_size: pagination.page_size, total:)
    |> models.page_to_json(models.transaction_to_json)
    |> json_ok(200)
  })
}

fn add_transaction(request: Request, ctx: Context, raw_id: String) -> Response {
  use body <- wisp.require_string_body(request)
  web.respond({
    use id <- result.try(web.parse_id(raw_id))
    use body <- result.try(
      json.parse(body, decode.dynamic)
      |> result.replace_error(BadRequest("request body must be JSON")),
    )
    use new <- result.try(
      models.parse_new_transaction(body) |> result.map_error(BadRequest),
    )
    use created <- result.map(store.add_transaction(ctx.db, id, new))
    created |> models.transaction_to_json |> json_ok(201)
  })
}

fn get_transaction(ctx: Context, raw_id: String) -> Response {
  web.respond({
    use id <- result.try(web.parse_id(raw_id))
    use transaction <- result.map(store.get_transaction(ctx.db, id))
    transaction |> models.transaction_to_json |> json_ok(200)
  })
}

fn json_ok(body: json.Json, status: Int) -> Response {
  body |> json.to_string |> wisp.json_response(status)
}

const swagger_ui = "<!doctype html>
<html lang=\"en\">
<head>
  <meta charset=\"utf-8\">
  <meta name=\"viewport\" content=\"width=device-width, initial-scale=1\">
  <title>ApiBattle API Docs</title>
  <link rel=\"stylesheet\" href=\"https://cdn.jsdelivr.net/npm/swagger-ui-dist@5.33.1/swagger-ui.css\">
</head>
<body>
  <div id=\"swagger-ui\"></div>
  <script src=\"https://cdn.jsdelivr.net/npm/swagger-ui-dist@5.33.1/swagger-ui-bundle.js\"></script>
  <script>
    window.ui = SwaggerUIBundle({ url: 'openapi.yaml', dom_id: '#swagger-ui' });
  </script>
</body>
</html>
"
