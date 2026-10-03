import helmet from "@fastify/helmet";
import Fastify, { LogController } from "fastify";
import { errorHandler } from "./errors.js";
import { accountRoutes } from "./routes/accounts.js";
import { docsRoutes } from "./routes/docs.js";
import { transactionRoutes } from "./routes/transactions.js";

export async function buildApp() {
  const app = Fastify({
    logger: { level: process.env.LOG_LEVEL ?? "info" },
    logController: new LogController({ disableRequestLogging: true }),
    bodyLimit: 64 * 1024,
    requestTimeout: 10_000,
    connectionTimeout: 10_000,
    // Keep-alive connections from nginx outlive its default 60s idle timeout.
    keepAliveTimeout: 65_000,
  });

  // Swagger UI needs inline scripts/styles, so CSP is left to the docs plugin.
  await app.register(helmet, { contentSecurityPolicy: false });

  app.setErrorHandler(errorHandler);
  app.setNotFoundHandler((_req, reply) => reply.code(404).send({ error: "not found" }));

  app.get("/health", (_req, reply) => reply.type("text/plain").send("ok"));
  await app.register(docsRoutes);
  await app.register(accountRoutes, { prefix: "/accounts" });
  await app.register(transactionRoutes, { prefix: "/transactions" });

  return app;
}
