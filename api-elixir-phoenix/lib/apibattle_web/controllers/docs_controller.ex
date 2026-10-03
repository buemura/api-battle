defmodule ApiBattleWeb.DocsController do
  use ApiBattleWeb, :controller

  @openapi_path Path.expand("../../../priv/openapi.yaml", __DIR__)
  @external_resource @openapi_path
  @openapi File.read!(@openapi_path)

  @swagger_ui """
  <!doctype html>
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

  def swagger_ui(conn, _params), do: html(conn, @swagger_ui)

  def spec(conn, _params) do
    conn
    |> put_resp_content_type("application/yaml")
    |> send_resp(200, @openapi)
  end
end
