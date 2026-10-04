import { Elysia } from "elysia";
import { ApiError } from "./errors";
import { accountRoutes } from "./routes/accounts";
import { docsRoutes } from "./routes/docs";
import { transactionRoutes } from "./routes/transactions";

const SECURITY_HEADERS = {
  "x-content-type-options": "nosniff",
  "x-frame-options": "SAMEORIGIN",
  "referrer-policy": "no-referrer",
  "strict-transport-security": "max-age=15552000; includeSubDomains",
};

export const app = new Elysia({
  serve: {
    maxRequestBodySize: 64 * 1024,
    idleTimeout: 10,
  },
})
  .error({ ApiError })
  .onRequest(({ request, set }) => {
    Object.assign(set.headers, SECURITY_HEADERS);
    set.headers["x-request-id"] = request.headers.get("x-request-id") ?? crypto.randomUUID();
  })
  .onError(({ code, error, set }) => {
    switch (code) {
      case "ApiError":
        set.status = error.status;
        return { error: error.message };
      case "VALIDATION":
        set.status = 400;
        // Every schema carries a custom `error`, which becomes the message.
        return { error: error.customError ?? error.message };
      case "PARSE":
        // Errors thrown by a route's own parser arrive wrapped in ParseError.
        if (error.cause instanceof ApiError) {
          set.status = error.cause.status;
          return { error: error.cause.message };
        }
        set.status = 400;
        return { error: "request body must be JSON" };
      case "NOT_FOUND":
        set.status = 404;
        return { error: "not found" };
      default:
        console.error("unhandled error", error);
        set.status = 500;
        return { error: "internal server error" };
    }
  })
  .get("/health", () => "ok")
  .use(docsRoutes)
  .use(accountRoutes)
  .use(transactionRoutes);
