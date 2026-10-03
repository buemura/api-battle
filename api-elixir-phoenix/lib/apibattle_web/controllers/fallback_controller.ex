defmodule ApiBattleWeb.FallbackController do
  @moduledoc "Renders `{:error, reason}` results as `{\"error\": \"<message>\"}`."

  use ApiBattleWeb, :controller

  def call(conn, {:error, reason}) do
    {status, message} = error(reason)

    conn
    |> put_status(status)
    |> json(%{error: message})
  end

  defp error({:invalid, message}), do: {:bad_request, message}
  defp error(:not_found), do: {:not_found, "not found"}
  defp error(:account_not_found), do: {:not_found, "account not found"}
  defp error(:transaction_not_found), do: {:not_found, "transaction not found"}
  defp error(:insufficient_funds), do: {:unprocessable_entity, "insufficient funds"}
end
