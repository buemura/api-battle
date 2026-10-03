# ---- build stage ----
FROM python:3.13-slim-bookworm AS build
COPY --from=ghcr.io/astral-sh/uv:0.9 /uv /usr/local/bin/uv
ENV UV_COMPILE_BYTECODE=1 UV_LINK_MODE=copy UV_PYTHON_DOWNLOADS=never
WORKDIR /app

# Cache dependencies separately from the application source.
COPY pyproject.toml uv.lock ./
RUN uv sync --locked --no-dev

# ---- runtime stage ----
FROM python:3.13-slim-bookworm
RUN useradd --system --no-create-home app
WORKDIR /app
COPY --from=build /app/.venv /app/.venv
COPY openapi.yaml ./
COPY app ./app
ENV PATH="/app/.venv/bin:$PATH" PYTHONUNBUFFERED=1 PORT=8080
USER app
EXPOSE 8080
HEALTHCHECK --interval=10s --timeout=3s --retries=3 \
    CMD python -c "import os, urllib.request; urllib.request.urlopen(f'http://localhost:{os.environ[\"PORT\"]}/health', timeout=2)" || exit 1
# Set PROCESSES / WORKERS to scale Robyn's processes and per-process Rust worker threads.
CMD ["python", "-m", "app.main"]
