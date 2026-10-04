/** An expected failure, rendered as `{"error": "<message>"}`. */
export class ApiError extends Error {
  constructor(
    readonly status: number,
    message: string,
  ) {
    super(message);
  }
}

export const badRequest = (message: string) => new ApiError(400, message);
export const notFound = (message: string) => new ApiError(404, message);
export const unprocessable = (message: string) => new ApiError(422, message);
