#pragma once

#include <drogon/HttpResponse.h>
#include <drogon/orm/Row.h>
#include <json/json.h>

#include <string>

namespace apibattle
{
// Columns selected for a transaction, with timestamps rendered as ISO-8601 UTC.
inline constexpr const char *kTransactionColumns =
    "id, account_id, type, amount, description, "
    "to_char(created_at AT TIME ZONE 'UTC', "
    "'YYYY-MM-DD\"T\"HH24:MI:SS.MS\"Z\"') AS created_at";

inline drogon::HttpResponsePtr jsonResponse(const Json::Value &body,
                                            drogon::HttpStatusCode status =
                                                drogon::k200OK)
{
    auto resp = drogon::HttpResponse::newHttpJsonResponse(body);
    resp->setStatusCode(status);
    return resp;
}

inline drogon::HttpResponsePtr jsonError(drogon::HttpStatusCode status,
                                         const std::string &message)
{
    Json::Value body;
    body["error"] = message;
    return jsonResponse(body, status);
}

inline Json::Value transactionToJson(const drogon::orm::Row &row)
{
    Json::Value json;
    json["id"] = Json::Int64(row["id"].as<int64_t>());
    json["account_id"] = Json::Int64(row["account_id"].as<int64_t>());
    json["type"] = row["type"].as<std::string>();
    json["amount"] = Json::Int64(row["amount"].as<int64_t>());
    json["description"] = row["description"].isNull()
                              ? Json::Value(Json::nullValue)
                              : Json::Value(row["description"].as<std::string>());
    json["created_at"] = row["created_at"].as<std::string>();
    return json;
}
}  // namespace apibattle
