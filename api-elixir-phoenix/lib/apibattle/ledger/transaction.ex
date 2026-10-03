defmodule ApiBattle.Ledger.Transaction do
  use Ecto.Schema

  # Rows are append-only (enforced by a trigger in db/init.sql).
  schema "transactions" do
    belongs_to :account, ApiBattle.Ledger.Account
    field :type, Ecto.Enum, values: [:credit, :debit]
    field :amount, :integer
    field :description, :string
    field :created_at, :utc_datetime_usec, read_after_writes: true
  end
end
