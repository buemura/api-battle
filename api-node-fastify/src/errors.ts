import type { FastifyError, FastifyReply, FastifyRequest } from "fastify";

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

// Fastify's own body parsing failures, reported in the API's wording.
const INVALID_BODY_CODES = new Set([
  "FST_ERR_CTP_INVALID_JSON_BODY",
  "FST_ERR_CTP_EMPTY_JSON_BODY",
  "FST_ERR_CTP_INVALID_MEDIA_TYPE",
]);

export function errorHandler(err: FastifyError | ApiError, req: FastifyRequest, reply: FastifyReply) {
  if (err instanceof ApiError) {
    return reply.code(err.statusCode).send({ error: err.message });
  }
  if ("code" in err && INVALID_BODY_CODES.has(err.code)) {
    return reply.code(400).send({ error: "request body must be JSON" });
  }
  if (err.statusCode && err.statusCode < 500) {
    return reply.code(err.statusCode).send({ error: err.message });
  }
  req.log.error({ err }, "unhandled error");
  return reply.code(500).send({ error: "internal server error" });
}
