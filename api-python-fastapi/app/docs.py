from pathlib import Path

from fastapi import APIRouter, Response
from fastapi.responses import HTMLResponse

router = APIRouter(include_in_schema=False)

# The hand-written spec is shared by every implementation of this API.
OPENAPI_SPEC = (Path(__file__).parent.parent / "openapi.yaml").read_text()

SWAGGER_UI_HTML = """<!doctype html>
<html lang="en">
<head>
  <meta charset="utf-8">
  <meta name="viewport" content="width=device-width, initial-scale=1">
  <title>ApiBattle API Docs</title>
  <link rel="stylesheet" href="https://cdn.jsdelivr.net/npm/swagger-ui-dist@5.33.1/swagger-ui.css">
</head>
<body>
  <div id="swagger-ui"></div>
  <script src="https://cdn.jsdelivr.net/npm/swagger-ui-dist@5.33.1/swagger-ui-bundle.js"></script>
  <script>
    window.ui = SwaggerUIBundle({ url: 'openapi.yaml', dom_id: '#swagger-ui' });
  </script>
</body>
</html>
"""


@router.get("/openapi.yaml")
async def spec() -> Response:
    return Response(OPENAPI_SPEC, media_type="application/yaml")


@router.get("/docs", response_class=HTMLResponse)
async def swagger_ui() -> str:
    return SWAGGER_UI_HTML
