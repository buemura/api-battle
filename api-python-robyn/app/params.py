from dataclasses import dataclass

from robyn import Request

from app.errors import bad_request, not_found
from app.schemas import MAX_BIGINT

DEFAULT_PAGE_SIZE = 20
MAX_PAGE_SIZE = 100


def resource_id(request: Request) -> int:
    """Non-numeric ids can never match a resource, so they are a 404, not a 400."""
    raw = request.path_params["id"]
    if not raw.isascii() or not raw.isdigit() or int(raw) > MAX_BIGINT:
        raise not_found()
    return int(raw)


@dataclass(frozen=True)
class Pagination:
    page: int
    page_size: int

    @property
    def offset(self) -> int:
        return (self.page - 1) * self.page_size


def _parse_positive(raw: str | None, fallback: int) -> int | None:
    if not raw:
        return fallback
    if not raw.isascii() or not raw.isdigit() or int(raw) < 1:
        return None
    return int(raw)


def pagination(request: Request) -> Pagination:
    page = _parse_positive(request.query_params.get("page", None), 1)
    page_size = _parse_positive(request.query_params.get("page_size", None), DEFAULT_PAGE_SIZE)
    if page is None or page_size is None or page_size > MAX_PAGE_SIZE:
        raise bad_request("'page' must be >= 1 and 'page_size' must be between 1 and 100")
    return Pagination(page, page_size)
