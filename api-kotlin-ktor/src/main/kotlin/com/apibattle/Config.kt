package com.apibattle

private fun env(key: String, fallback: String): String = System.getenv(key)?.takeIf { it.isNotEmpty() } ?: fallback

private fun envInt(key: String, fallback: Int): Int = System.getenv(key)?.toIntOrNull() ?: fallback

data class DbConfig(
    val host: String,
    val port: Int,
    val name: String,
    val user: String,
    val password: String,
    val poolSize: Int,
) {
    val jdbcUrl get() = "jdbc:postgresql://$host:$port/$name"
}

data class Config(val port: Int, val db: DbConfig) {
    companion object {
        fun fromEnv() = Config(
            port = envInt("PORT", 8080),
            db = DbConfig(
                host = env("DB_HOST", "localhost"),
                port = envInt("DB_PORT", 5432),
                name = env("DB_NAME", "apibattle"),
                user = env("DB_USER", "apibattle"),
                password = env("DB_PASSWORD", "apibattle"),
                poolSize = envInt("DB_POOL_SIZE", 10),
            ),
        )
    }
}
