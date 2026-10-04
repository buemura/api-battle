import { bigint, pgTable, timestamp, varchar } from "drizzle-orm/pg-core";

// Mirrors db/init.sql, which owns the schema. BIGINT columns are read as JS
// numbers: ids and minor-unit amounts stay well below 2^53.
export const accounts = pgTable("accounts", {
  id: bigint("id", { mode: "number" }).primaryKey().generatedAlwaysAsIdentity(),
  name: varchar("name", { length: 100 }).notNull(),
  createdAt: timestamp("created_at", { withTimezone: true }).notNull().defaultNow(),
});

export const transactions = pgTable("transactions", {
  id: bigint("id", { mode: "number" }).primaryKey().generatedAlwaysAsIdentity(),
  accountId: bigint("account_id", { mode: "number" })
    .notNull()
    .references(() => accounts.id),
  type: varchar("type", { length: 6, enum: ["credit", "debit"] }).notNull(),
  amount: bigint("amount", { mode: "number" }).notNull(),
  description: varchar("description", { length: 255 }),
  createdAt: timestamp("created_at", { withTimezone: true }).notNull().defaultNow(),
});

export type TransactionType = (typeof transactions.type.enumValues)[number];
