import { asc, count, desc, eq, sql } from "drizzle-orm";
import { Elysia } from "elysia";
import { db } from "../db/client";
import { accounts, transactions } from "../db/schema";
import { notFound, unprocessable } from "../errors";
import {
  newTransactionBody,
  normalizeNewTransaction,
  pageBounds,
  paginationQuery,
  parseId,
  parseJsonObject,
  parsePagination,
} from "../validation";

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

export const accountRoutes = new Elysia({ prefix: "/accounts" })
  .get(
    "/",
    async ({ query }) => {
      const pagination = parsePagination(query);
      const { limit, offset } = pageBounds(pagination);

      const [[{ total } = { total: 0 }], data] = await Promise.all([
        db.select({ total: count() }).from(accounts),
        db.select(accountColumns).from(accounts).orderBy(asc(accounts.id)).limit(limit).offset(offset),
      ]);

      return { data, ...pagination, total };
    },
    { query: paginationQuery },
  )

  .get("/:id", async ({ params }) => {
    const id = parseId(params.id);
    const [account] = await db.select(accountColumns).from(accounts).where(eq(accounts.id, id));
    if (!account) throw notFound("account not found");
    return account;
  })

  .get(
    "/:id/transactions",
    async ({ params, query }) => {
      const id = parseId(params.id);
      const pagination = parsePagination(query);
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

      return { data, ...pagination, total: account.total };
    },
    { query: paginationQuery },
  )

  .post(
    "/:id/transactions",
    async ({ params, body, set }) => {
      const id = parseId(params.id);
      const input = normalizeNewTransaction(body);

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

      set.status = 201;
      return created;
    },
    { parse: parseJsonObject, body: newTransactionBody },
  );
