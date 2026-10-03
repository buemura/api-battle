#pragma once

#include <drogon/HttpController.h>

using drogon::HttpRequestPtr;
using drogon::HttpResponsePtr;
using drogon::Task;

class TransactionController
    : public drogon::HttpController<TransactionController>
{
  public:
    METHOD_LIST_BEGIN
    ADD_METHOD_TO(TransactionController::getTransaction,
                  "/transactions/{id}",
                  drogon::Get);
    METHOD_LIST_END

    Task<HttpResponsePtr> getTransaction(HttpRequestPtr req, int64_t id);
};
