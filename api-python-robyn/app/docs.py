from pathlib import Path

from robyn import Response, Robyn

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


def register(app: Robyn) -> None:
    @app.get("/openapi.yaml", const=True)
    def spec() -> Response:
        return Response(200, {"Content-Type": "application/yaml"}, body=OPENAPI_SPEC)

    @app.get("/docs", const=True)
    def swagger_ui() -> Response:
        return Response(200, {"Content-Type": "text/html; charset=utf-8"}, body=SWAGGER_UI_HTML)
