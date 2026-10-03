from fastapi import APIRouter, status
from fastapi.responses import PlainTextResponse
from sqlalchemy import BigInteger, Select, case, cast, func, select

from app.dependencies import PageParams, ResourceId, Session
from app.errors import not_found, unprocessable
from app.models import Account, Transaction
from app.schemas import AccountOut, Page, TransactionIn, TransactionOut

router = APIRouter()

signed_amount = case((Transaction.type == "credit", Transaction.amount), else_=-Transaction.amount)


def balance_of(account_id) -> Select:
    return select(cast(func.coalesce(func.sum(signed_amount), 0), BigInteger)).where(
        Transaction.account_id == account_id
    )


# Accounts with their balance derived from the ledger.
balance = balance_of(Account.id).correlate(Account).scalar_subquery().label("balance")
account_select = select(Account.id, Account.name, Account.created_at, balance)


@router.get("/health", response_class=PlainTextResponse)
async def health() -> str:
    return "ok"


@router.get("/accounts")
async def list_accounts(session: Session, pagination: PageParams) -> Page[AccountOut]:
    total = await session.scalar(select(func.count()).select_from(Account))
    rows = await session.execute(
        account_select.order_by(Account.id).limit(pagination.page_size).offset(pagination.offset)
    )
    return Page(
        data=[AccountOut.model_validate(row) for row in rows],
        page=pagination.page,
        page_size=pagination.page_size,
        total=total,
    )


@router.get("/accounts/{id}")
async def get_account(session: Session, id: ResourceId) -> AccountOut:
    row = (await session.execute(account_select.where(Account.id == id))).one_or_none()
    if row is None:
        raise not_found("account not found")
    return AccountOut.model_validate(row)


@router.get("/accounts/{id}/transactions")
async def list_transactions(
    session: Session, id: ResourceId, pagination: PageParams
) -> Page[TransactionOut]:
    tx_count = (
        select(func.count())
        .where(Transaction.account_id == Account.id)
        .correlate(Account)
        .scalar_subquery()
    )
    total = await session.scalar(select(tx_count).where(Account.id == id))
    if total is None:
        raise not_found("account not found")

    transactions = await session.scalars(
        select(Transaction)
        .where(Transaction.account_id == id)
        .order_by(Transaction.id.desc())
        .limit(pagination.page_size)
        .offset(pagination.offset)
    )
    return Page(
        data=[TransactionOut.model_validate(t) for t in transactions],
        page=pagination.page,
        page_size=pagination.page_size,
        total=total,
    )


@router.post("/accounts/{id}/transactions", status_code=status.HTTP_201_CREATED)
async def add_transaction(session: Session, id: ResourceId, body: TransactionIn) -> TransactionOut:
    async with session.begin():
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
    return TransactionOut.model_validate(transaction)


@router.get("/transactions/{id}")
async def get_transaction(session: Session, id: ResourceId) -> TransactionOut:
    transaction = await session.get(Transaction, id)
    if transaction is None:
        raise not_found("transaction not found")
    return TransactionOut.model_validate(transaction)
