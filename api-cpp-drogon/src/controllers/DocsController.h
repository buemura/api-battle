#pragma once

#include <drogon/HttpController.h>

class DocsController : public drogon::HttpController<DocsController>
{
  public:
    METHOD_LIST_BEGIN
    ADD_METHOD_TO(DocsController::spec, "/openapi.yaml", drogon::Get);
    ADD_METHOD_TO(DocsController::swaggerUi, "/docs", drogon::Get);
    METHOD_LIST_END

    void spec(const drogon::HttpRequestPtr &req,
              std::function<void(const drogon::HttpResponsePtr &)> &&callback);
    void swaggerUi(
        const drogon::HttpRequestPtr &req,
        std::function<void(const drogon::HttpResponsePtr &)> &&callback);
};
