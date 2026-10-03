import envoy
import gleam/erlang/process
import gleam/int
import gleam/option.{Some}
import gleam/otp/static_supervisor as supervisor
import gleam/result
import mist
import apibattle_api/router
import apibattle_api/web.{Context}
import pog
import simplifile
import wisp
import wisp/wisp_mist

pub fn main() -> Nil {
  wisp.configure_logger()

  let pool_name = process.new_name("apibattle_db")
  let db_config =
    pog.default_config(pool_name)
    |> pog.host(env_or("DB_HOST", "localhost"))
    |> pog.port(env_int("DB_PORT", 5432))
    |> pog.database(env_or("DB_NAME", "apibattle"))
    |> pog.user(env_or("DB_USER", "apibattle"))
    |> pog.password(Some(env_or("DB_PASSWORD", "apibattle")))
    |> pog.pool_size(env_int("DB_POOL_SIZE", 10))

  let assert Ok(priv) = wisp.priv_directory("apibattle_api")
  let assert Ok(openapi_spec) = simplifile.read(priv <> "/openapi.yaml")
  let ctx = Context(db: pog.named_connection(pool_name), openapi_spec:)

  // No cookies or signed messages are used, so the key is never relied on.
  let secret_key_base = env_or("SECRET_KEY_BASE", wisp.random_string(64))
  let port = env_int("PORT", 8080)

  let http_server =
    wisp_mist.handler(router.handle_request(_, ctx), secret_key_base)
    |> mist.new
    |> mist.bind("0.0.0.0")
    |> mist.port(port)
    |> mist.after_start(fn(_, _, _) {
      wisp.log_info("ApiBattle API listening on 0.0.0.0:" <> int.to_string(port))
    })
    |> mist.supervised

  let assert Ok(_) =
    supervisor.new(supervisor.OneForOne)
    |> supervisor.add(pog.supervised(db_config))
    |> supervisor.add(http_server)
    |> supervisor.start

  process.sleep_forever()
}

fn env_or(key: String, fallback: String) -> String {
  case envoy.get(key) {
    Ok("") | Error(_) -> fallback
    Ok(value) -> value
  }
}

fn env_int(key: String, fallback: Int) -> Int {
  envoy.get(key) |> result.try(int.parse) |> result.unwrap(fallback)
}
