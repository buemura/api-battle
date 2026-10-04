import { eq } from "drizzle-orm";
import { Elysia } from "elysia";
import { db } from "../db/client";
import { transactions } from "../db/schema";
import { notFound } from "../errors";
import { parseId } from "../validation";
import { transactionColumns } from "./accounts";

export const transactionRoutes = new Elysia({ prefix: "/transactions" }).get("/:id", async ({ params }) => {
  const id = parseId(params.id);
  const [transaction] = await db
    .select(transactionColumns)
    .from(transactions)
    .where(eq(transactions.id, id));
  if (!transaction) throw notFound("transaction not found");
  return transaction;
});
