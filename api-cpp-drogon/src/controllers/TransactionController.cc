#include "TransactionController.h"

#include "http_utils.h"

#include <drogon/drogon.h>

using namespace drogon;
using namespace apibattle;

Task<HttpResponsePtr> TransactionController::getTransaction(HttpRequestPtr req,
                                                            int64_t id)
{
    try
    {
        auto db = app().getDbClient();
        auto result = co_await db->execSqlCoro(
            std::string("SELECT ") + kTransactionColumns +
                " FROM transactions WHERE id = $1",
            id);
        if (result.empty())
            co_return jsonError(k404NotFound, "transaction not found");
        co_return jsonResponse(transactionToJson(result[0]));
    }
    catch (const orm::DrogonDbException &e)
    {
        LOG_ERROR << "Database error: " << e.base().what();
        co_return jsonError(k500InternalServerError, "internal server error");
    }
}
