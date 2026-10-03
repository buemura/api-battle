defmodule ApiBattle.Ledger.Account do
  use Ecto.Schema

  schema "accounts" do
    field :name, :string
    field :balance, :integer, virtual: true
    field :created_at, :utc_datetime_usec, read_after_writes: true
  end
end
