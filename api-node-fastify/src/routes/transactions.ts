import { eq } from "drizzle-orm";
import type { FastifyPluginAsync } from "fastify";
import { db } from "../db/client.js";
import { transactions } from "../db/schema.js";
import { notFound } from "../errors.js";
import { parseId } from "../validation.js";
import { transactionColumns } from "./accounts.js";

export const transactionRoutes: FastifyPluginAsync = async (app) => {
  app.get<{ Params: { id: string } }>("/:id", async (req) => {
    const id = parseId(req.params.id);
    const [transaction] = await db
      .select(transactionColumns)
      .from(transactions)
      .where(eq(transactions.id, id));
    if (!transaction) throw notFound("transaction not found");
    return transaction;
  });
};
