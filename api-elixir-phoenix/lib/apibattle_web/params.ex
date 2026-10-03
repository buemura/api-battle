defmodule ApiBattleWeb.Params do
  @moduledoc "Parsing of path ids and pagination query params."

  @max_bigint 9_223_372_036_854_775_807
  @max_page 4_294_967_295
  @default_page_size 20
  @max_page_size 100

  @doc """
  Parses a numeric path id. Ids that are not a valid bigint can never match a
  resource, so they are reported as not found.
  """
  def id(raw) do
    case Integer.parse(raw) do
      {id, ""} when id >= 1 and id <= @max_bigint -> {:ok, id}
      _ -> {:error, :not_found}
    end
  end

  def pagination(params) do
    with {:ok, page} <- positive(params["page"], 1, @max_page),
         {:ok, page_size} <- positive(params["page_size"], @default_page_size, @max_page_size) do
      {:ok, %{page: page, page_size: page_size, limit: page_size, offset: (page - 1) * page_size}}
    else
      _ -> {:error, {:invalid, "'page' must be >= 1 and 'page_size' must be between 1 and 100"}}
    end
  end

  defp positive(raw, default, _max) when raw in [nil, ""], do: {:ok, default}

  defp positive(raw, _default, max) when is_binary(raw) do
    case Integer.parse(raw) do
      {value, ""} when value >= 1 and value <= max -> {:ok, value}
      _ -> :error
    end
  end

  defp positive(_raw, _default, _max), do: :error
end
