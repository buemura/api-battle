#pragma once

#include <drogon/HttpController.h>

using drogon::HttpRequestPtr;
using drogon::HttpResponsePtr;
using drogon::Task;

class AccountController : public drogon::HttpController<AccountController>
{
  public:
    METHOD_LIST_BEGIN
    ADD_METHOD_TO(AccountController::listAccounts, "/accounts", drogon::Get);
    ADD_METHOD_TO(AccountController::getAccount, "/accounts/{id}", drogon::Get);
    ADD_METHOD_TO(AccountController::listTransactions,
                  "/accounts/{id}/transactions",
                  drogon::Get);
    ADD_METHOD_TO(AccountController::addTransaction,
                  "/accounts/{id}/transactions",
                  drogon::Post);
    METHOD_LIST_END

    Task<HttpResponsePtr> listAccounts(HttpRequestPtr req);
    Task<HttpResponsePtr> getAccount(HttpRequestPtr req, int64_t id);
    Task<HttpResponsePtr> listTransactions(HttpRequestPtr req, int64_t id);
    Task<HttpResponsePtr> addTransaction(HttpRequestPtr req, int64_t id);
};
