import { asc, count, desc, eq, sql } from "drizzle-orm";
import { Router } from "express";
import { db } from "../db/client.js";
import { accounts, transactions } from "../db/schema.js";
import { badRequest, notFound, unprocessable } from "../errors.js";
import { pageBounds, parseId, parseNewTransaction, parsePagination } from "../validation.js";

// Balance is always derived from the ledger: credits minus debits.
const signedAmount = sql`CASE WHEN ${transactions.type} = 'credit' THEN ${transactions.amount} ELSE -${transactions.amount} END`;

// Correlated subqueries are written with explicit aliases: Drizzle renders
// columns unqualified in single-table selects, so `${accounts.id}` would bind
// to the subquery's own `transactions.id`.
const accountColumns = {
  id: accounts.id,
  name: accounts.name,
  balance: sql<number>`COALESCE((
    SELECT SUM(CASE WHEN t.type = 'credit' THEN t.amount ELSE -t.amount END)
    FROM transactions t WHERE t.account_id = accounts.id
  ), 0)::bigint`.mapWith(Number),
  created_at: accounts.createdAt,
};

export const transactionColumns = {
  id: transactions.id,
  account_id: transactions.accountId,
  type: transactions.type,
  amount: transactions.amount,
  description: transactions.description,
  created_at: transactions.createdAt,
};

export const accountRoutes = Router();

accountRoutes.get("/", async (req, res) => {
  const pagination = parsePagination(req.query);
  const { limit, offset } = pageBounds(pagination);

  const [[{ total } = { total: 0 }], data] = await Promise.all([
    db.select({ total: count() }).from(accounts),
    db.select(accountColumns).from(accounts).orderBy(asc(accounts.id)).limit(limit).offset(offset),
  ]);

  res.json({ data, ...pagination, total });
});

accountRoutes.get("/:id", async (req, res) => {
  const id = parseId(req.params.id);
  const [account] = await db.select(accountColumns).from(accounts).where(eq(accounts.id, id));
  if (!account) throw notFound("account not found");
  res.json(account);
});

accountRoutes.get("/:id/transactions", async (req, res) => {
  const id = parseId(req.params.id);
  const pagination = parsePagination(req.query);
  const { limit, offset } = pageBounds(pagination);

  const [account] = await db
    .select({
      total: sql<number>`(SELECT count(*) FROM transactions t WHERE t.account_id = accounts.id)`.mapWith(Number),
    })
    .from(accounts)
    .where(eq(accounts.id, id));
  if (!account) throw notFound("account not found");

  const data = await db
    .select(transactionColumns)
    .from(transactions)
    .where(eq(transactions.accountId, id))
    .orderBy(desc(transactions.id))
    .limit(limit)
    .offset(offset);

  res.json({ data, ...pagination, total: account.total });
});

accountRoutes.post("/:id/transactions", async (req, res) => {
  const id = parseId(req.params.id);
  // express.json() leaves the body undefined for non-JSON content types.
  if (req.body === undefined) throw badRequest("request body must be JSON");
  const input = parseNewTransaction(req.body);

  const created = await db.transaction(async (tx) => {
    // Lock the account row so concurrent debits can't overdraw it.
    const [account] = await tx
      .select({ id: accounts.id })
      .from(accounts)
      .where(eq(accounts.id, id))
      .for("update");
    if (!account) throw notFound("account not found");

    if (input.type === "debit") {
      const [{ balance } = { balance: 0 }] = await tx
        .select({ balance: sql<number>`COALESCE(SUM(${signedAmount}), 0)::bigint`.mapWith(Number) })
        .from(transactions)
        .where(eq(transactions.accountId, id));
      if (balance < input.amount) throw unprocessable("insufficient funds");
    }

    const [row] = await tx
      .insert(transactions)
      .values({ accountId: id, ...input })
      .returning(transactionColumns);
    return row;
  });

  res.status(201).json(created);
});
