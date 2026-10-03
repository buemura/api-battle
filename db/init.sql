CREATE TABLE accounts (
    id         BIGINT GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
    name       VARCHAR(100) NOT NULL,
    created_at TIMESTAMPTZ  NOT NULL DEFAULT now()
);

-- Amounts are stored in minor units (e.g. cents) and are always positive;
-- `type` determines whether they add to or subtract from the balance.
CREATE TABLE transactions (
    id          BIGINT GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
    account_id  BIGINT       NOT NULL REFERENCES accounts (id),
    type        VARCHAR(6)   NOT NULL CHECK (type IN ('credit', 'debit')),
    amount      BIGINT       NOT NULL CHECK (amount > 0),
    description VARCHAR(255),
    created_at  TIMESTAMPTZ  NOT NULL DEFAULT now()
);

CREATE INDEX idx_transactions_account_id_id ON transactions (account_id, id DESC);

-- The ledger is append-only: reject any UPDATE or DELETE on transactions.
CREATE FUNCTION reject_ledger_mutation() RETURNS trigger AS $$
BEGIN
    RAISE EXCEPTION 'transactions are immutable';
END;
$$ LANGUAGE plpgsql;

CREATE TRIGGER transactions_immutable
    BEFORE UPDATE OR DELETE ON transactions
    FOR EACH ROW EXECUTE FUNCTION reject_ledger_mutation();

-- Seed accounts. IDs are fixed so clients can rely on them.
INSERT INTO accounts (id, name) OVERRIDING SYSTEM VALUE VALUES
    (1000, 'Account 1000'),
    (2000, 'Account 2000');
