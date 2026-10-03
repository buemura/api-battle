import { Hono } from "hono";
import { bodyLimit } from "hono/body-limit";
import { HTTPException } from "hono/http-exception";
import { requestId } from "hono/request-id";
import { secureHeaders } from "hono/secure-headers";
import { timeout } from "hono/timeout";
import { errorHandler } from "./errors";
import { docsRoutes } from "./routes/docs";
import { accountRoutes } from "./routes/accounts";
import { transactionRoutes } from "./routes/transactions";

export const app = new Hono()
  .use(requestId())
  .use(secureHeaders())
  .use(timeout(10_000, () => new HTTPException(408, { message: "request timeout" })))
  .use(
    bodyLimit({
      maxSize: 64 * 1024,
      onError: (c) => c.json({ error: "request body too large" }, 413),
    }),
  )
  .get("/health", (c) => c.text("ok"))
  .route("/", docsRoutes)
  .route("/accounts", accountRoutes)
  .route("/transactions", transactionRoutes)
  .notFound((c) => c.json({ error: "not found" }, 404))
  .onError(errorHandler);
