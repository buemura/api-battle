import { app } from "./app";
import { config } from "./config";
import { sql } from "./db/client";

const server = Bun.serve({
  port: config.port,
  fetch: app.fetch,
});

console.log(`ApiBattle API listening on ${server.url}`);

async function shutdown(signal: string) {
  console.log(`${signal} received, shutting down`);
  await server.stop();
  await sql.end({ timeout: 5 });
  process.exit(0);
}

process.on("SIGINT", () => shutdown("SIGINT"));
process.on("SIGTERM", () => shutdown("SIGTERM"));
