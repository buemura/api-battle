import logging
from collections.abc import AsyncIterator
from contextlib import asynccontextmanager

import uvicorn
from fastapi import FastAPI

from app import docs, routes
from app.config import settings
from app.db import engine
from app.errors import register_error_handlers

logging.basicConfig(level=logging.INFO, format="%(asctime)s %(levelname)s %(name)s %(message)s")


@asynccontextmanager
async def lifespan(_: FastAPI) -> AsyncIterator[None]:
    yield
    await engine.dispose()


# FastAPI's generated docs are disabled in favour of the shared openapi.yaml.
app = FastAPI(
    title="ApiBattle API", lifespan=lifespan, docs_url=None, redoc_url=None, openapi_url=None
)
app.include_router(routes.router)
app.include_router(docs.router)
register_error_handlers(app)


if __name__ == "__main__":
    uvicorn.run("app.main:app", host="0.0.0.0", port=settings.port)
