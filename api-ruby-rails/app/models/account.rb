class Account < ApplicationRecord
  has_many :transactions

  # Balance is always derived from the ledger.
  BALANCE = Arel.sql(<<~SQL.squish)
    COALESCE((SELECT SUM(#{Transaction::SIGNED_AMOUNT}) FROM transactions
              WHERE transactions.account_id = accounts.id), 0)::bigint AS balance
  SQL

  scope :with_balance, -> { select(:id, :name, :created_at, BALANCE) }

  def as_json(*)
    { id:, name:, balance: self[:balance], created_at: created_at.iso8601(3) }
  end
end
