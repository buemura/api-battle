import Config

config :apibattle, ecto_repos: [ApiBattle.Repo]

config :apibattle, ApiBattleWeb.Endpoint,
  adapter: Bandit.PhoenixAdapter,
  render_errors: [formats: [json: ApiBattleWeb.ErrorJSON], layout: false]

config :logger, :default_formatter,
  format: "$time $metadata[$level] $message\n",
  metadata: [:request_id]

config :phoenix, :json_library, Jason

if config_env() == :prod do
  config :logger, level: :info
end
