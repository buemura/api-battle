import logging

from robyn import Robyn
from robyn.argument_parser import Config

from app import docs, routes
from app.config import settings
from app.db import engine
from app.errors import handle_exception


def create_app() -> Robyn:
    config = Config()
    # Robyn's generated docs are disabled in favour of the shared openapi.yaml.
    config.disable_openapi = True
    config.log_level = "WARN"
    config.processes = settings.processes
    config.workers = settings.workers

    app = Robyn(__file__, config=config)
    # Robyn binds the exception handler when a route is added, so set it first.
    app.exception(handle_exception)
    routes.register(app)
    docs.register(app)

    @app.shutdown_handler
    async def dispose_engine() -> None:
        await engine.dispose()

    return app


app = create_app()


if __name__ == "__main__":
    logging.basicConfig(level=logging.INFO, format="%(asctime)s %(levelname)s %(name)s %(message)s")
    app.start(host="0.0.0.0", port=settings.port, _check_port=False)
