from dataclasses import dataclass
from typing import Annotated

from fastapi import Depends
from sqlalchemy.ext.asyncio import AsyncSession

from app.db import get_session
from app.errors import bad_request, not_found
from app.schemas import MAX_BIGINT

DEFAULT_PAGE_SIZE = 20
MAX_PAGE_SIZE = 100

Session = Annotated[AsyncSession, Depends(get_session)]


def parse_id(id: str) -> int:
    """Non-numeric ids can never match a resource, so they are a 404, not a 400."""
    if not id.isascii() or not id.isdigit() or int(id) > MAX_BIGINT:
        raise not_found()
    return int(id)


ResourceId = Annotated[int, Depends(parse_id)]


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


# Query params are taken as raw strings so malformed values get our JSON error
# message instead of FastAPI's generic validation response.
def parse_pagination(page: str | None = None, page_size: str | None = None) -> Pagination:
    parsed_page = _parse_positive(page, 1)
    parsed_size = _parse_positive(page_size, DEFAULT_PAGE_SIZE)
    if parsed_page is None or parsed_size is None or parsed_size > MAX_PAGE_SIZE:
        raise bad_request("'page' must be >= 1 and 'page_size' must be between 1 and 100")
    return Pagination(parsed_page, parsed_size)


PageParams = Annotated[Pagination, Depends(parse_pagination)]
