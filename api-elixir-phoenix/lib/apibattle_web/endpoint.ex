defmodule ApiBattleWeb.Endpoint do
  use Phoenix.Endpoint, otp_app: :apibattle

  plug Plug.RequestId
  # Per-request logs at debug level, so they stay out of production output.
  plug Plug.Telemetry, event_prefix: [:phoenix, :endpoint], log: :debug

  plug Plug.Parsers,
    parsers: [:json],
    pass: ["*/*"],
    json_decoder: Phoenix.json_library()

  plug ApiBattleWeb.Router
end
