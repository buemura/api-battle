import { Elysia } from "elysia";
import spec from "../../openapi.yaml" with { type: "text" };

const SWAGGER_UI_HTML = `<!doctype html>
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
`;

export const docsRoutes = new Elysia()
  .get("/docs", () => new Response(SWAGGER_UI_HTML, { headers: { "Content-Type": "text/html; charset=utf-8" } }))
  .get("/openapi.yaml", () => new Response(spec, { headers: { "Content-Type": "application/yaml" } }));
