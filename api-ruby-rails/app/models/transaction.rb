class Transaction < ApplicationRecord
  TYPES = %w[credit debit].freeze
  SIGNED_AMOUNT = "CASE WHEN transactions.type = 'credit' THEN transactions.amount ELSE -transactions.amount END".freeze

  # `type` is a plain column here, not Single Table Inheritance.
  self.inheritance_column = nil

  # The account is already locked by the caller and the FK is enforced by the
  # database, so skip the presence query `belongs_to` would run on create.
  belongs_to :account, optional: true

  def self.balance_of(account_id)
    where(account_id:).sum(Arel.sql(SIGNED_AMOUNT)).to_i
  end

  def as_json(*)
    { id:, account_id:, type:, amount:, description:, created_at: created_at.iso8601(3) }
  end
end
