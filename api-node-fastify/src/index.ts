import { buildApp } from "./app.js";
import { config } from "./config.js";
import { pool } from "./db/client.js";

const app = await buildApp();
await app.listen({ host: "0.0.0.0", port: config.port });

async function shutdown(signal: string) {
  app.log.info(`${signal} received, shutting down`);
  await app.close();
  await pool.end();
  process.exit(0);
}

process.on("SIGINT", () => shutdown("SIGINT"));
process.on("SIGTERM", () => shutdown("SIGTERM"));
