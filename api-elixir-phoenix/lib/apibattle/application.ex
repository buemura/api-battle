defmodule ApiBattle.Application do
  @moduledoc false

  use Application

  @impl true
  def start(_type, _args) do
    children = [
      ApiBattle.Repo,
      ApiBattleWeb.Endpoint
    ]

    Supervisor.start_link(children, strategy: :one_for_one, name: ApiBattle.Supervisor)
  end

  @impl true
  def config_change(changed, _new, removed) do
    ApiBattleWeb.Endpoint.config_change(changed, removed)
    :ok
  end
end
