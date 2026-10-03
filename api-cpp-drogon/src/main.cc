#include <drogon/drogon.h>

#include <cstdlib>
#include <string>

namespace
{
std::string env(const char *key, const std::string &fallback)
{
    const char *value = std::getenv(key);
    return value && *value ? value : fallback;
}
}  // namespace

int main()
{
    drogon::orm::PostgresConfig db{};
    db.host = env("DB_HOST", "localhost");
    db.port = static_cast<unsigned short>(std::stoi(env("DB_PORT", "5432")));
    db.databaseName = env("DB_NAME", "apibattle");
    db.username = env("DB_USER", "apibattle");
    db.password = env("DB_PASSWORD", "apibattle");
    db.connectionNumber = std::stoul(env("DB_POOL_SIZE", "10"));
    db.name = "default";
    db.isFast = false;
    db.timeout = 5.0;
    db.autoBatch = false;

    const auto port = static_cast<uint16_t>(std::stoi(env("PORT", "8080")));
    LOG_INFO << "ApiBattle API listening on port " << port;

    drogon::app()
        .addDbClient(db)
        .addListener("0.0.0.0", port)
        .setThreadNum(std::stoi(env("THREADS", "0")))  // 0 = one per CPU core
        .setLogLevel(trantor::Logger::kInfo)
        .registerHandler(
            "/health",
            [](const drogon::HttpRequestPtr &,
               std::function<void(const drogon::HttpResponsePtr &)> &&callback) {
                auto resp = drogon::HttpResponse::newHttpResponse();
                resp->setBody("ok");
                callback(resp);
            },
            {drogon::Get})
        .run();
}
