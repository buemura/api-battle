package com.apibattle.api;

import jakarta.ws.rs.GET;
import jakarta.ws.rs.Path;
import jakarta.ws.rs.Produces;
import jakarta.ws.rs.core.MediaType;
import java.io.IOException;
import java.io.InputStream;
import java.io.UncheckedIOException;

@Path("/")
public class DocsResource {

    private static final String SWAGGER_UI_HTML = """
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

    private final byte[] openApiYaml;

    public DocsResource() {
        try (InputStream in = DocsResource.class.getResourceAsStream("/openapi.yaml")) {
            this.openApiYaml = in.readAllBytes();
        } catch (IOException e) {
            throw new UncheckedIOException(e);
        }
    }

    @GET
    @Path("openapi.yaml")
    @Produces("application/yaml")
    public byte[] openApiSpec() {
        return openApiYaml;
    }

    @GET
    @Path("docs")
    @Produces(MediaType.TEXT_HTML)
    public String swaggerUi() {
        return SWAGGER_UI_HTML;
    }
}
