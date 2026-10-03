from sqlalchemy.ext.asyncio import async_sessionmaker, create_async_engine

from app.config import settings

# Connections are opened lazily, so each Robyn process fills its own pool on
# its own event loop.
engine = create_async_engine(
    settings.database_url,
    pool_size=settings.db_pool_size,
    max_overflow=0,
    pool_timeout=5,
    pool_pre_ping=True,
)
SessionLocal = async_sessionmaker(engine, expire_on_commit=False)
