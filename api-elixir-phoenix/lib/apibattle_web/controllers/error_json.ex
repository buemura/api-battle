defmodule ApiBattleWeb.ErrorJSON do
  @moduledoc "Renders errors raised outside controllers (bad JSON, unknown routes, crashes)."

  def render(_template, %{reason: %Plug.Parsers.ParseError{}}),
    do: %{error: "request body must be JSON"}

  def render("500.json", _assigns), do: %{error: "internal server error"}

  def render(template, _assigns) do
    %{error: template |> Phoenix.Controller.status_message_from_template() |> String.downcase()}
  end
end
