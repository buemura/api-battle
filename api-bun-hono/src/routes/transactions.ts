import { eq } from "drizzle-orm";
import { Hono } from "hono";
import { db } from "../db/client";
import { transactions } from "../db/schema";
import { notFound } from "../errors";
import { parseId } from "../validation";
import { transactionColumns } from "./accounts";

export const transactionRoutes = new Hono().get("/:id", async (c) => {
  const id = parseId(c);
  const [transaction] = await db
    .select(transactionColumns)
    .from(transactions)
    .where(eq(transactions.id, id));
  if (!transaction) throw notFound("transaction not found");
  return c.json(transaction);
});
