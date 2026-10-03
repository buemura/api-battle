defmodule ApiBattleWeb.LedgerJSON do
  alias ApiBattle.Ledger.{Account, Transaction}

  def page(items, %{page: page, page_size: page_size}, total, render) do
    %{data: Enum.map(items, render), page: page, page_size: page_size, total: total}
  end

  def account(%Account{} = account) do
    %{
      id: account.id,
      name: account.name,
      balance: account.balance,
      created_at: timestamp(account.created_at)
    }
  end

  def transaction(%Transaction{} = transaction) do
    %{
      id: transaction.id,
      account_id: transaction.account_id,
      type: transaction.type,
      amount: transaction.amount,
      description: transaction.description,
      created_at: timestamp(transaction.created_at)
    }
  end

  # ISO-8601 UTC with millisecond precision, e.g. `2026-10-03T02:44:35.274Z`.
  defp timestamp(datetime),
    do: datetime |> DateTime.truncate(:millisecond) |> DateTime.to_iso8601()
end
