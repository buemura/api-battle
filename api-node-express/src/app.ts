import express from "express";
import helmet from "helmet";
import { pinoHttp } from "pino-http";
import { errorHandler, notFoundHandler } from "./errors.js";
import { logger } from "./logger.js";
import { accountRoutes } from "./routes/accounts.js";
import { docsRoutes } from "./routes/docs.js";
import { transactionRoutes } from "./routes/transactions.js";

export function buildApp() {
  const app = express();
  app.disable("x-powered-by");
  app.set("etag", false);

  // Swagger UI needs inline scripts/styles, so CSP is disabled.
  app.use(helmet({ contentSecurityPolicy: false }));
  // Attaches req.log; per-request access logs are off to keep the hot path lean.
  app.use(pinoHttp({ logger, autoLogging: false }));
  app.use(express.json({ limit: "64kb" }));

  app.get("/health", (_req, res) => {
    res.type("text/plain").send("ok");
  });
  app.use(docsRoutes);
  app.use("/accounts", accountRoutes);
  app.use("/transactions", transactionRoutes);

  app.use(notFoundHandler);
  app.use(errorHandler);

  return app;
}
