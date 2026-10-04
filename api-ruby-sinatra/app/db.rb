require "sequel"

module ApiBattle
  # Each Puma worker gets its own pool, sized to its thread count.
  DB = Sequel.connect(
    adapter: "postgres",
    host: ENV.fetch("DB_HOST", "localhost"),
    port: Integer(ENV.fetch("DB_PORT", 5432)),
    database: ENV.fetch("DB_NAME", "apibattle"),
    user: ENV.fetch("DB_USER", "apibattle"),
    password: ENV.fetch("DB_PASSWORD", "apibattle"),
    max_connections: Integer(ENV.fetch("MAX_THREADS", 2)),
    pool_timeout: 5,
    test: false,
  )
  Sequel.default_timezone = :utc

  # The schema is owned by db/init.sql: `created_at` comes from the column
  # default and is returned by INSERT ... RETURNING.
  Sequel::Model.plugin :insert_returning_select
  Sequel::Model.plugin :subclasses

  SIGNED_AMOUNT = Sequel.case({ { type: "credit" } => :amount }, Sequel.*(:amount, -1))

  class Transaction < Sequel::Model(DB[:transactions])
    TYPES = %w[credit debit].freeze

    many_to_one :account

    def self.balance_of(account_id)
      where(account_id:).sum(SIGNED_AMOUNT).to_i
    end

    def to_h
      { id:, account_id:, type:, amount:, description:, created_at: created_at.utc.iso8601(3) }
    end
  end

  class Account < Sequel::Model(DB[:accounts])
    one_to_many :transactions

    # Balance is always derived from the ledger.
    BALANCE = DB[:transactions]
      .where(account_id: Sequel[:accounts][:id])
      .select { coalesce(sum(SIGNED_AMOUNT), 0) }

    dataset_module do
      def with_balance
        select(:id, :name, :created_at, Sequel.cast(BALANCE, :bigint).as(:balance))
      end
    end

    def to_h
      { id:, name:, balance: self[:balance], created_at: created_at.utc.iso8601(3) }
    end
  end

  Sequel::Model.freeze_descendants
  DB.freeze
end
