defmodule ApiBattleWeb.AccountController do
  use ApiBattleWeb, :controller

  alias ApiBattle.Ledger
  alias ApiBattleWeb.{LedgerJSON, Params}

  action_fallback ApiBattleWeb.FallbackController

  def index(conn, params) do
    with {:ok, pagination} <- Params.pagination(params) do
      {accounts, total} = Ledger.list_accounts(pagination)
      json(conn, LedgerJSON.page(accounts, pagination, total, &LedgerJSON.account/1))
    end
  end

  def show(conn, %{"id" => id}) do
    with {:ok, id} <- Params.id(id),
         {:ok, account} <- Ledger.get_account(id) do
      json(conn, LedgerJSON.account(account))
    end
  end
end
