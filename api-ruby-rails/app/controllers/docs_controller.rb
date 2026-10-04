class DocsController < ApplicationController
  # The hand-written spec is shared by every implementation of this API.
  SPEC = Rails.root.join("openapi.yaml").read.freeze

  UI = <<~HTML.freeze
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
  HTML

  def ui
    render html: UI.html_safe
  end

  def spec
    render plain: SPEC, content_type: "application/yaml"
  end
end
