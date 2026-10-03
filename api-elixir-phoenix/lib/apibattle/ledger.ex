defmodule ApiBattle.Ledger do
  @moduledoc """
  Accounts and their append-only transactions. Balances are always derived
  from the ledger (credits minus debits), never stored.
  """

  import Ecto.Query

  alias ApiBattle.Repo
  alias ApiBattle.Ledger.{Account, Transaction}

  @max_bigint 9_223_372_036_854_775_807
  @max_description_length 255

  def list_accounts(%{limit: limit, offset: offset}) do
    total = Repo.aggregate(Account, :count)

    accounts =
      accounts_with_balance()
      |> order_by(:id)
      |> limit(^limit)
      |> offset(^offset)
      |> Repo.all()

    {accounts, total}
  end

  def get_account(id) do
    case accounts_with_balance() |> where(id: ^id) |> Repo.one() do
      nil -> {:error, :account_not_found}
      account -> {:ok, account}
    end
  end

  def list_transactions(account_id, %{limit: limit, offset: offset}) do
    # Checks the account exists and counts its transactions in one round trip.
    total =
      from(a in Account,
        where: a.id == ^account_id,
        select: fragment("(SELECT count(*) FROM transactions WHERE account_id = ?)", a.id)
      )
      |> Repo.one()

    if total do
      transactions =
        from(t in Transaction,
          where: t.account_id == ^account_id,
          order_by: [desc: t.id],
          limit: ^limit,
          offset: ^offset
        )
        |> Repo.all()

      {:ok, {transactions, total}}
    else
      {:error, :account_not_found}
    end
  end

  def get_transaction(id) do
    case Repo.get(Transaction, id) do
      nil -> {:error, :transaction_not_found}
      transaction -> {:ok, transaction}
    end
  end

  def create_transaction(account_id, params) do
    with {:ok, attrs} <- validate_transaction(params) do
      Repo.transact(fn ->
        with :ok <- lock_account(account_id),
             :ok <- ensure_funds(account_id, attrs) do
          %Transaction{account_id: account_id}
          |> struct!(attrs)
          |> Repo.insert()
        end
      end)
    end
  end

  # Locking the account row serializes writes per account, so concurrent
  # debits can't overdraw it.
  defp lock_account(account_id) do
    from(a in Account, where: a.id == ^account_id, lock: "FOR UPDATE", select: a.id)
    |> Repo.one()
    |> case do
      nil -> {:error, :account_not_found}
      _ -> :ok
    end
  end

  defp ensure_funds(_account_id, %{type: :credit}), do: :ok

  defp ensure_funds(account_id, %{type: :debit, amount: amount}) do
    balance =
      from(t in Transaction,
        where: t.account_id == ^account_id,
        select:
          fragment(
            "COALESCE(SUM(CASE WHEN ? = 'credit' THEN ? ELSE -? END), 0)::bigint",
            t.type,
            t.amount,
            t.amount
          )
      )
      |> Repo.one()

    if balance >= amount, do: :ok, else: {:error, :insufficient_funds}
  end

  defp accounts_with_balance do
    from a in Account,
      select_merge: %{
        balance:
          fragment(
            "(SELECT COALESCE(SUM(CASE WHEN t.type = 'credit' THEN t.amount ELSE -t.amount END), 0)::bigint FROM transactions t WHERE t.account_id = ?)",
            a.id
          )
      }
  end

  # Validated field by field so each problem gets a specific message.
  defp validate_transaction(params) do
    with {:ok, type} <- validate_type(params["type"]),
         {:ok, amount} <- validate_amount(params["amount"]),
         {:ok, description} <- validate_description(params["description"]) do
      {:ok, %{type: type, amount: amount, description: description}}
    end
  end

  defp validate_type("credit"), do: {:ok, :credit}
  defp validate_type("debit"), do: {:ok, :debit}
  defp validate_type(_), do: {:error, {:invalid, "'type' must be either 'credit' or 'debit'"}}

  defp validate_amount(amount) when is_integer(amount) and amount > 0 and amount <= @max_bigint,
    do: {:ok, amount}

  defp validate_amount(_),
    do: {:error, {:invalid, "'amount' must be a positive integer (minor units, e.g. cents)"}}

  defp validate_description(nil), do: {:ok, nil}
  defp validate_description(""), do: {:ok, nil}

  defp validate_description(description) when is_binary(description) do
    # Postgres VARCHAR(n) counts codepoints, not graphemes.
    if length(String.codepoints(description)) <= @max_description_length,
      do: {:ok, description},
      else: invalid_description()
  end

  defp validate_description(_), do: invalid_description()

  defp invalid_description,
    do: {:error, {:invalid, "'description' must be a string of at most 255 characters"}}
end
