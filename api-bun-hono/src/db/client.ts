import { drizzle } from "drizzle-orm/postgres-js";
import postgres from "postgres";
import { config } from "../config";
import * as schema from "./schema";

export const sql = postgres({
  host: config.db.host,
  port: config.db.port,
  database: config.db.database,
  username: config.db.username,
  password: config.db.password,
  max: config.db.poolSize,
  connect_timeout: 5,
  idle_timeout: 30,
});

export const db = drizzle(sql, { schema });

export type Db = typeof db;
