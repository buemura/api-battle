#include "AccountController.h"

#include "http_utils.h"

#include <drogon/drogon.h>

#include <charconv>
#include <coroutine>
#include <optional>

using namespace drogon;
using namespace apibattle;

namespace
{
constexpr int kDefaultPageSize = 20;
constexpr int kMaxPageSize = 100;
constexpr size_t kMaxDescriptionLength = 255;

constexpr const char *kBalanceSql =
    "SELECT COALESCE(SUM(CASE WHEN type = 'credit' THEN amount ELSE -amount "
    "END), 0)::bigint AS balance FROM transactions WHERE account_id = $1";

// Accounts with their balance derived from the ledger. Callers append a WHERE
// and/or ORDER BY clause.
constexpr const char *kAccountSelect =
    "SELECT a.id, a.name, "
    "to_char(a.created_at AT TIME ZONE 'UTC', "
    "'YYYY-MM-DD\"T\"HH24:MI:SS.MS\"Z\"') AS created_at, "
    "COALESCE(b.balance, 0) AS balance "
    "FROM accounts a LEFT JOIN LATERAL ("
    "SELECT SUM(CASE WHEN t.type = 'credit' THEN t.amount ELSE -t.amount "
    "END)::bigint AS balance FROM transactions t WHERE t.account_id = a.id"
    ") b ON true";

Json::Value accountToJson(const orm::Row &row)
{
    Json::Value json;
    json["id"] = Json::Int64(row["id"].as<int64_t>());
    json["name"] = row["name"].as<std::string>();
    json["balance"] = Json::Int64(row["balance"].as<int64_t>());
    json["created_at"] = row["created_at"].as<std::string>();
    return json;
}

// Parses a positive integer query parameter; returns fallback when absent and
// std::nullopt when present but invalid.
std::optional<int> positiveIntParam(const HttpRequestPtr &req,
                                    const std::string &name,
                                    int fallback)
{
    const auto &raw = req->getParameter(name);
    if (raw.empty())
        return fallback;
    int value = 0;
    auto [ptr, ec] = std::from_chars(raw.data(), raw.data() + raw.size(), value);
    if (ec != std::errc() || ptr != raw.data() + raw.size() || value < 1)
        return std::nullopt;
    return value;
}

struct Pagination
{
    int page;
    int pageSize;

    int64_t offset() const
    {
        return static_cast<int64_t>(page - 1) * pageSize;
    }
};

// Reads `page` and `page_size`; std::nullopt when either is invalid.
std::optional<Pagination> paginationParams(const HttpRequestPtr &req)
{
    const auto page = positiveIntParam(req, "page", 1);
    const auto pageSize = positiveIntParam(req, "page_size", kDefaultPageSize);
    if (!page || !pageSize || *pageSize > kMaxPageSize)
        return std::nullopt;
    return Pagination{*page, *pageSize};
}

HttpResponsePtr invalidPagination()
{
    return jsonError(
        k400BadRequest,
        "'page' must be >= 1 and 'page_size' must be between 1 and 100");
}

Json::Value pageToJson(Json::Value data, const Pagination &p, int64_t total)
{
    Json::Value json;
    json["data"] = std::move(data);
    json["page"] = p.page;
    json["page_size"] = p.pageSize;
    json["total"] = Json::Int64(total);
    return json;
}

// Drogon commits a transaction when its last reference is dropped and reports
// the outcome via a callback. This awaiter drops the reference and resumes the
// coroutine once COMMIT has finished, so we never respond before the data is
// durable (or report success for a commit that failed).
struct CommitAwaiter
{
    std::shared_ptr<orm::Transaction> tx;
    bool committed = false;

    bool await_ready() const noexcept
    {
        return false;
    }

    void await_suspend(std::coroutine_handle<> handle)
    {
        tx->setCommitCallback([this, handle](bool ok) {
            committed = ok;
            handle.resume();
        });
        // Release from a stack local: the callback may resume (and destroy)
        // this coroutine frame, so no members are touched afterwards.
        auto last = std::move(tx);
        last.reset();
    }

    bool await_resume() const noexcept
    {
        return committed;
    }
};

HttpResponsePtr dbError(const orm::DrogonDbException &e)
{
    LOG_ERROR << "Database error: " << e.base().what();
    return jsonError(k500InternalServerError, "internal server error");
}
}  // namespace

Task<HttpResponsePtr> AccountController::listAccounts(HttpRequestPtr req)
{
    const auto pagination = paginationParams(req);
    if (!pagination)
        co_return invalidPagination();

    try
    {
        auto db = app().getDbClient();
        auto count =
            co_await db->execSqlCoro("SELECT count(*) AS total FROM accounts");
        auto rows = co_await db->execSqlCoro(
            std::string(kAccountSelect) + " ORDER BY a.id LIMIT $1 OFFSET $2",
            static_cast<int64_t>(pagination->pageSize),
            pagination->offset());

        Json::Value data(Json::arrayValue);
        for (const auto &row : rows)
            data.append(accountToJson(row));
        co_return jsonResponse(pageToJson(std::move(data),
                                          *pagination,
                                          count[0]["total"].as<int64_t>()));
    }
    catch (const orm::DrogonDbException &e)
    {
        co_return dbError(e);
    }
}

Task<HttpResponsePtr> AccountController::getAccount(HttpRequestPtr req,
                                                    int64_t id)
{
    try
    {
        auto db = app().getDbClient();
        auto result = co_await db->execSqlCoro(
            std::string(kAccountSelect) + " WHERE a.id = $1", id);
        if (result.empty())
            co_return jsonError(k404NotFound, "account not found");
        co_return jsonResponse(accountToJson(result[0]));
    }
    catch (const orm::DrogonDbException &e)
    {
        co_return dbError(e);
    }
}

Task<HttpResponsePtr> AccountController::listTransactions(HttpRequestPtr req,
                                                          int64_t id)
{
    const auto pagination = paginationParams(req);
    if (!pagination)
        co_return invalidPagination();

    try
    {
        auto db = app().getDbClient();
        auto count = co_await db->execSqlCoro(
            "SELECT (SELECT count(*) FROM transactions WHERE account_id = a.id) "
            "AS total FROM accounts a WHERE a.id = $1",
            id);
        if (count.empty())
            co_return jsonError(k404NotFound, "account not found");

        auto rows = co_await db->execSqlCoro(
            std::string("SELECT ") + kTransactionColumns +
                " FROM transactions WHERE account_id = $1 "
                "ORDER BY id DESC LIMIT $2 OFFSET $3",
            id,
            static_cast<int64_t>(pagination->pageSize),
            pagination->offset());

        Json::Value data(Json::arrayValue);
        for (const auto &row : rows)
            data.append(transactionToJson(row));
        co_return jsonResponse(pageToJson(std::move(data),
                                          *pagination,
                                          count[0]["total"].as<int64_t>()));
    }
    catch (const orm::DrogonDbException &e)
    {
        co_return dbError(e);
    }
}

Task<HttpResponsePtr> AccountController::addTransaction(HttpRequestPtr req,
                                                        int64_t id)
{
    auto body = req->getJsonObject();
    if (!body)
        co_return jsonError(k400BadRequest, "request body must be JSON");

    const auto &typeJson = (*body)["type"];
    const auto type = typeJson.isString() ? typeJson.asString() : "";
    if (type != "credit" && type != "debit")
        co_return jsonError(k400BadRequest,
                            "'type' must be either 'credit' or 'debit'");

    const auto &amountJson = (*body)["amount"];
    if (!amountJson.isInt64() || amountJson.asInt64() <= 0)
        co_return jsonError(
            k400BadRequest,
            "'amount' must be a positive integer (minor units, e.g. cents)");
    const int64_t amount = amountJson.asInt64();

    const auto &descriptionJson = (*body)["description"];
    if (!descriptionJson.isNull() &&
        (!descriptionJson.isString() ||
         descriptionJson.asString().size() > kMaxDescriptionLength))
        co_return jsonError(
            k400BadRequest,
            "'description' must be a string of at most 255 characters");

    try
    {
        auto db = app().getDbClient();
        auto tx = co_await db->newTransactionCoro();

        // Lock the account row so concurrent debits can't overdraw it.
        auto account = co_await tx->execSqlCoro(
            "SELECT id FROM accounts WHERE id = $1 FOR UPDATE", id);
        if (account.empty())
        {
            tx->rollback();
            co_return jsonError(k404NotFound, "account not found");
        }

        if (type == "debit")
        {
            auto balance = co_await tx->execSqlCoro(kBalanceSql, id);
            if (balance[0]["balance"].as<int64_t>() < amount)
            {
                tx->rollback();
                co_return jsonError(k422UnprocessableEntity,
                                    "insufficient funds");
            }
        }

        auto inserted = co_await tx->execSqlCoro(
            std::string("INSERT INTO transactions (account_id, type, amount, "
                        "description) VALUES ($1, $2, $3, NULLIF($4, '')) "
                        "RETURNING ") +
                kTransactionColumns,
            id,
            type,
            amount,
            descriptionJson.isNull() ? std::string() : descriptionJson.asString());

        auto json = transactionToJson(inserted[0]);
        if (!co_await CommitAwaiter{std::move(tx)})
            co_return jsonError(k500InternalServerError,
                                "failed to commit transaction");
        co_return jsonResponse(json, k201Created);
    }
    catch (const orm::DrogonDbException &e)
    {
        co_return dbError(e);
    }
}
