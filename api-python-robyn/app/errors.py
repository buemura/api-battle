import json
import logging

from pydantic import ValidationError
from robyn import Response

logger = logging.getLogger("apibattle")

JSON_HEADERS = {"Content-Type": "application/json"}

FIELD_MESSAGES = {
    "type": "'type' must be either 'credit' or 'debit'",
    "amount": "'amount' must be a positive integer (minor units, e.g. cents)",
    "description": "'description' must be a string of at most 255 characters",
}


class ApiError(Exception):
    """Every non-2xx response is rendered as `{"error": "<message>"}`."""

    def __init__(self, status_code: int, message: str):
        self.status_code = status_code
        self.message = message


def bad_request(message: str) -> ApiError:
    return ApiError(400, message)


def not_found(message: str = "not found") -> ApiError:
    return ApiError(404, message)


def unprocessable(message: str) -> ApiError:
    return ApiError(422, message)


def error_response(status_code: int, message: str) -> Response:
    return Response(status_code, JSON_HEADERS, body=json.dumps({"error": message}))


def validation_error(exc: ValidationError) -> ApiError:
    # Report the first offending field with a specific message, checked in
    # declaration order so the output is deterministic.
    fields = {err["loc"][0] for err in exc.errors() if err["loc"]}
    for field, message in FIELD_MESSAGES.items():
        if field in fields:
            return bad_request(message)
    return bad_request("request body must be JSON")


def handle_exception(exc: Exception) -> Response:
    if isinstance(exc, ApiError):
        return error_response(exc.status_code, exc.message)
    logger.exception("unhandled error", exc_info=exc)
    return error_response(500, "internal server error")
