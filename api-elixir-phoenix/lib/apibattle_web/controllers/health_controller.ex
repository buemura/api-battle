defmodule ApiBattleWeb.HealthController do
  use ApiBattleWeb, :controller

  def show(conn, _params), do: text(conn, "ok")
end
