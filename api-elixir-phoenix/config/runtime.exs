import Config

# Same environment variables as the other implementations (see docker-compose.yml).
env = fn key, default ->
  case System.get_env(key) do
    value when value in [nil, ""] -> default
    value -> value
  end
end

config :apibattle, ApiBattle.Repo,
  hostname: env.("DB_HOST", "localhost"),
  port: String.to_integer(env.("DB_PORT", "5432")),
  database: env.("DB_NAME", "apibattle"),
  username: env.("DB_USER", "apibattle"),
  password: env.("DB_PASSWORD", "apibattle"),
  pool_size: String.to_integer(env.("DB_POOL_SIZE", "10"))

config :apibattle, ApiBattleWeb.Endpoint,
  server: true,
  http: [ip: {0, 0, 0, 0}, port: String.to_integer(env.("PORT", "8080"))]
