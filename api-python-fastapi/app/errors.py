import logging

from fastapi import FastAPI, Request
from fastapi.exceptions import RequestValidationError
from fastapi.responses import JSONResponse
from starlette.exceptions import HTTPException as StarletteHTTPException

logger = logging.getLogger("apibattle")

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


def _error(status_code: int, message: str) -> JSONResponse:
    return JSONResponse({"error": message}, status_code=status_code)


def _validation_message(exc: RequestValidationError) -> str:
    # Report the first offending field with a specific message, checked in
    # declaration order so the output is deterministic.
    fields = {err["loc"][1] for err in exc.errors() if len(err["loc"]) > 1}
    for field, message in FIELD_MESSAGES.items():
        if field in fields:
            return message
    return "request body must be JSON"


def register_error_handlers(app: FastAPI) -> None:
    @app.exception_handler(ApiError)
    async def api_error(_: Request, exc: ApiError) -> JSONResponse:
        return _error(exc.status_code, exc.message)

    @app.exception_handler(RequestValidationError)
    async def validation_error(_: Request, exc: RequestValidationError) -> JSONResponse:
        return _error(400, _validation_message(exc))

    @app.exception_handler(StarletteHTTPException)
    async def http_error(_: Request, exc: StarletteHTTPException) -> JSONResponse:
        message = "not found" if exc.status_code == 404 else str(exc.detail).lower()
        return _error(exc.status_code, message)

    @app.exception_handler(Exception)
    async def unhandled_error(_: Request, exc: Exception) -> JSONResponse:
        logger.exception("unhandled error", exc_info=exc)
        return _error(500, "internal server error")
