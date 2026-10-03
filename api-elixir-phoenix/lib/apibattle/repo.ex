defmodule ApiBattle.Repo do
  use Ecto.Repo,
    otp_app: :apibattle,
    adapter: Ecto.Adapters.Postgres
end
