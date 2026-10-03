import type { Context } from "hono";
import { HTTPException } from "hono/http-exception";
import type { ContentfulStatusCode } from "hono/utils/http-status";

/** An expected failure, rendered as `{"error": "<message>"}`. */
export class ApiError extends Error {
  constructor(
    readonly status: ContentfulStatusCode,
    message: string,
  ) {
    super(message);
  }
}

export const badRequest = (message: string) => new ApiError(400, message);
export const notFound = (message: string) => new ApiError(404, message);
export const unprocessable = (message: string) => new ApiError(422, message);

export function errorHandler(err: Error, c: Context) {
  if (err instanceof ApiError || err instanceof HTTPException) {
    return c.json({ error: err.message }, err.status as ContentfulStatusCode);
  }
  console.error("unhandled error", err);
  return c.json({ error: "internal server error" }, 500);
}
