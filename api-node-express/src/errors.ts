import type { ErrorRequestHandler, RequestHandler } from "express";

/** An expected failure, rendered as `{"error": "<message>"}`. */
export class ApiError extends Error {
  constructor(
    readonly statusCode: number,
    message: string,
  ) {
    super(message);
  }
}

export const badRequest = (message: string) => new ApiError(400, message);
export const notFound = (message: string) => new ApiError(404, message);
export const unprocessable = (message: string) => new ApiError(422, message);

export const notFoundHandler: RequestHandler = (_req, res) => {
  res.status(404).json({ error: "not found" });
};

// body-parser failures carry a `type` and an HTTP `status`.
type HttpError = Error & { status?: number; type?: string };

export const errorHandler: ErrorRequestHandler = (err: HttpError, req, res, _next) => {
  if (err instanceof ApiError) {
    res.status(err.statusCode).json({ error: err.message });
    return;
  }
  if (err.type === "entity.parse.failed") {
    res.status(400).json({ error: "request body must be JSON" });
    return;
  }
  if (err.status && err.status < 500) {
    res.status(err.status).json({ error: err.message });
    return;
  }
  req.log.error({ err }, "unhandled error");
  res.status(500).json({ error: "internal server error" });
};
