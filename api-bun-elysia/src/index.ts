import { app } from "./app";
import { config } from "./config";
import { sql } from "./db/client";

app.listen(config.port);

console.log(`ApiBattle API listening on ${app.server?.url}`);

async function shutdown(signal: string) {
  console.log(`${signal} received, shutting down`);
  await app.stop();
  await sql.end({ timeout: 5 });
  process.exit(0);
}

process.on("SIGINT", () => shutdown("SIGINT"));
process.on("SIGTERM", () => shutdown("SIGTERM"));
