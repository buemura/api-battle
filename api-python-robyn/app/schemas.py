from datetime import UTC, datetime
from typing import Annotated, Literal

from pydantic import BaseModel, ConfigDict, Field, PlainSerializer, StrictInt, StrictStr

MAX_BIGINT = 2**63 - 1

# ISO-8601 UTC with millisecond precision, e.g. 2026-10-03T02:44:35.274Z
IsoTimestamp = Annotated[
    datetime,
    PlainSerializer(
        lambda ts: ts.astimezone(UTC).isoformat(timespec="milliseconds").replace("+00:00", "Z")
    ),
]


class AccountOut(BaseModel):
    model_config = ConfigDict(from_attributes=True)

    id: int
    name: str
    balance: int
    created_at: IsoTimestamp


class TransactionOut(BaseModel):
    model_config = ConfigDict(from_attributes=True)

    id: int
    account_id: int
    type: Literal["credit", "debit"]
    amount: int
    description: str | None
    created_at: IsoTimestamp


class TransactionIn(BaseModel):
    type: Literal["credit", "debit"]
    amount: Annotated[StrictInt, Field(gt=0, le=MAX_BIGINT)]
    description: Annotated[StrictStr, Field(max_length=255)] | None = None


class Page[T](BaseModel):
    data: list[T]
    page: int
    page_size: int
    total: int
