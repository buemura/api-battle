package com.apibattle.api;

import java.io.IOException;
import org.springframework.core.io.ClassPathResource;
import org.springframework.http.MediaType;
import org.springframework.http.ResponseEntity;
import org.springframework.web.bind.annotation.GetMapping;
import org.springframework.web.bind.annotation.RestController;

@RestController
public class DocsController {

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

    public DocsController() throws IOException {
        this.openApiYaml = new ClassPathResource("openapi.yaml").getContentAsByteArray();
    }

    @GetMapping(value = "/openapi.yaml")
    ResponseEntity<byte[]> openApiSpec() {
        return ResponseEntity.ok().contentType(MediaType.parseMediaType("application/yaml")).body(openApiYaml);
    }

    @GetMapping(value = "/docs", produces = MediaType.TEXT_HTML_VALUE)
    String swaggerUi() {
        return SWAGGER_UI_HTML;
    }
}
