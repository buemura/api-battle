import { buildApp } from "./app.js";
import { config } from "./config.js";
import { pool } from "./db/client.js";
import { logger } from "./logger.js";

const server = buildApp().listen(config.port, "0.0.0.0", () => {
  logger.info(`listening on :${config.port}`);
});
server.requestTimeout = 10_000;
// Keep-alive connections from nginx outlive its default 60s idle timeout.
server.keepAliveTimeout = 65_000;
server.headersTimeout = 66_000;

function shutdown(signal: string) {
  logger.info(`${signal} received, shutting down`);
  server.close(async () => {
    await pool.end();
    process.exit(0);
  });
  server.closeIdleConnections();
}

process.on("SIGINT", () => shutdown("SIGINT"));
process.on("SIGTERM", () => shutdown("SIGTERM"));
