namespace ApiBattleApi;

public static class Docs
{
    private static readonly string OpenApiSpec = LoadSpec();

    private const string SwaggerUiHtml = """
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
        """;

    public static void MapDocs(this IEndpointRouteBuilder app)
    {
        app.MapGet("/docs", () => TypedResults.Content(SwaggerUiHtml, "text/html; charset=utf-8"));
        app.MapGet("/openapi.yaml", () => TypedResults.Content(OpenApiSpec, "application/yaml"));
    }

    private static string LoadSpec()
    {
        using var stream = typeof(Docs).Assembly.GetManifestResourceStream("openapi.yaml")
            ?? throw new InvalidOperationException("embedded openapi.yaml not found");
        using var reader = new StreamReader(stream);
        return reader.ReadToEnd();
    }
}
