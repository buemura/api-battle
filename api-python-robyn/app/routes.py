from pydantic import ValidationError
from robyn import Request, Response, Robyn
from sqlalchemy import BigInteger, Select, case, cast, func, select

from app.db import SessionLocal
from app.errors import JSON_HEADERS, not_found, unprocessable, validation_error
from app.models import Account, Transaction
from app.params import pagination, resource_id
from app.schemas import AccountOut, Page, TransactionIn, TransactionOut

signed_amount = case((Transaction.type == "credit", Transaction.amount), else_=-Transaction.amount)


def balance_of(account_id) -> Select:
    return select(cast(func.coalesce(func.sum(signed_amount), 0), BigInteger)).where(
        Transaction.account_id == account_id
    )


# Accounts with their balance derived from the ledger.
balance = balance_of(Account.id).correlate(Account).scalar_subquery().label("balance")
account_select = select(Account.id, Account.name, Account.created_at, balance)


async def health() -> str:
    return "ok"


async def list_accounts(request: Request) -> Page[AccountOut]:
    paging = pagination(request)
    async with SessionLocal() as session:
        total = await session.scalar(select(func.count()).select_from(Account))
        rows = await session.execute(
            account_select.order_by(Account.id).limit(paging.page_size).offset(paging.offset)
        )
    return Page(
        data=[AccountOut.model_validate(row) for row in rows],
        page=paging.page,
        page_size=paging.page_size,
        total=total,
    )


async def get_account(request: Request) -> AccountOut:
    id = resource_id(request)
    async with SessionLocal() as session:
        row = (await session.execute(account_select.where(Account.id == id))).one_or_none()
    if row is None:
        raise not_found("account not found")
    return AccountOut.model_validate(row)


async def list_transactions(request: Request) -> Page[TransactionOut]:
    id = resource_id(request)
    paging = pagination(request)
    tx_count = (
        select(func.count())
        .where(Transaction.account_id == Account.id)
        .correlate(Account)
        .scalar_subquery()
    )
    async with SessionLocal() as session:
        total = await session.scalar(select(tx_count).where(Account.id == id))
        if total is None:
            raise not_found("account not found")

        transactions = await session.scalars(
            select(Transaction)
            .where(Transaction.account_id == id)
            .order_by(Transaction.id.desc())
            .limit(paging.page_size)
            .offset(paging.offset)
        )
        data = [TransactionOut.model_validate(t) for t in transactions]
    return Page(data=data, page=paging.page, page_size=paging.page_size, total=total)


async def add_transaction(request: Request) -> Response:
    id = resource_id(request)
    # Validated by hand rather than via Robyn's pydantic injection, which
    # answers 422 with its own error shape instead of our 400 contract.
    try:
        body = TransactionIn.model_validate_json(request.body or b"")
    except ValidationError as exc:
        raise validation_error(exc) from None

    async with SessionLocal() as session, session.begin():
        # Lock the account row so concurrent debits can't overdraw it.
        locked = await session.scalar(select(Account.id).where(Account.id == id).with_for_update())
        if locked is None:
            raise not_found("account not found")

        if body.type == "debit" and await session.scalar(balance_of(id)) < body.amount:
            raise unprocessable("insufficient funds")

        transaction = Transaction(
            account_id=id,
            type=body.type,
            amount=body.amount,
            description=body.description or None,
        )
        session.add(transaction)
        await session.flush()
        await session.refresh(transaction)
    # Robyn renders returned pydantic models as 200 before applying a route's
    # `status_code`, so the 201 has to be set on an explicit Response.
    created = TransactionOut.model_validate(transaction).model_dump_json()
    return Response(201, JSON_HEADERS, body=created)


async def get_transaction(request: Request) -> TransactionOut:
    id = resource_id(request)
    async with SessionLocal() as session:
        transaction = await session.get(Transaction, id)
    if transaction is None:
        raise not_found("transaction not found")
    return TransactionOut.model_validate(transaction)


def register(app: Robyn) -> None:
    app.get("/health")(health)
    app.get("/accounts")(list_accounts)
    app.get("/accounts/:id")(get_account)
    app.get("/accounts/:id/transactions")(list_transactions)
    app.post("/accounts/:id/transactions")(add_transaction)
    app.get("/transactions/:id")(get_transaction)
