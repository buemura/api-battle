<?php

namespace App\Http\Controllers;

use Illuminate\Http\Response;

class DocsController extends Controller
{
    private const SWAGGER_UI_HTML = <<<'HTML'
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
        HTML;

    public function ui(): Response
    {
        return response(self::SWAGGER_UI_HTML)->header('Content-Type', 'text/html; charset=utf-8');
    }

    public function spec(): Response
    {
        return response(file_get_contents(base_path('openapi.yaml')))->header('Content-Type', 'application/yaml');
    }
}
