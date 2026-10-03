defmodule ApiBattleWeb.TransactionController do
  use ApiBattleWeb, :controller

  alias ApiBattle.Ledger
  alias ApiBattleWeb.{LedgerJSON, Params}

  action_fallback ApiBattleWeb.FallbackController

  def index(conn, %{"account_id" => account_id} = params) do
    with {:ok, account_id} <- account_id(account_id),
         {:ok, pagination} <- Params.pagination(params),
         {:ok, {transactions, total}} <- Ledger.list_transactions(account_id, pagination) do
      json(conn, LedgerJSON.page(transactions, pagination, total, &LedgerJSON.transaction/1))
    end
  end

  def create(conn, %{"account_id" => account_id}) do
    with {:ok, account_id} <- account_id(account_id),
         {:ok, transaction} <- Ledger.create_transaction(account_id, conn.body_params) do
      conn
      |> put_status(:created)
      |> json(LedgerJSON.transaction(transaction))
    end
  end

  def show(conn, %{"id" => id}) do
    with {:ok, id} <- Params.id(id),
         {:ok, transaction} <- Ledger.get_transaction(id) do
      json(conn, LedgerJSON.transaction(transaction))
    end
  end

  defp account_id(raw) do
    with {:error, :not_found} <- Params.id(raw), do: {:error, :account_not_found}
  end
end
