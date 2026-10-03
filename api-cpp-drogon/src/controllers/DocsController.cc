#include "DocsController.h"

#include "openapi_spec.h"

using namespace drogon;

namespace
{
constexpr const char *kSwaggerUiHtml = R"HTML(<!doctype html>
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
)HTML";
}  // namespace

void DocsController::spec(
    const HttpRequestPtr &,
    std::function<void(const HttpResponsePtr &)> &&callback)
{
    auto resp = HttpResponse::newHttpResponse();
    resp->setContentTypeString("application/yaml");
    resp->setBody(apibattle::kOpenApiSpec);
    callback(resp);
}

void DocsController::swaggerUi(
    const HttpRequestPtr &,
    std::function<void(const HttpResponsePtr &)> &&callback)
{
    auto resp = HttpResponse::newHttpResponse();
    resp->setContentTypeCode(CT_TEXT_HTML);
    resp->setBody(kSwaggerUiHtml);
    callback(resp);
}
