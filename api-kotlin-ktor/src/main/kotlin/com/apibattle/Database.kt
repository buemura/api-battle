package com.apibattle

import com.zaxxer.hikari.HikariConfig
import com.zaxxer.hikari.HikariDataSource
import kotlinx.coroutines.Dispatchers
import org.jetbrains.exposed.sql.Database
import org.jetbrains.exposed.sql.Expression
import org.jetbrains.exposed.sql.ExpressionWithColumnType
import org.jetbrains.exposed.sql.LongColumnType
import org.jetbrains.exposed.sql.QueryBuilder
import org.jetbrains.exposed.sql.Table
import org.jetbrains.exposed.sql.Transaction
import org.jetbrains.exposed.sql.javatime.CurrentTimestampWithTimeZone
import org.jetbrains.exposed.sql.javatime.timestampWithTimeZone
import org.jetbrains.exposed.sql.transactions.experimental.newSuspendedTransaction

// The schema is owned by db/init.sql; these mappings only describe it.
object Accounts : Table("accounts") {
    val id = long("id").autoIncrement()
    val name = varchar("name", 100)
    val createdAt = timestampWithTimeZone("created_at").defaultExpression(CurrentTimestampWithTimeZone)

    override val primaryKey = PrimaryKey(id)
}

object Transactions : Table("transactions") {
    val id = long("id").autoIncrement()
    val accountId = long("account_id").references(Accounts.id)
    val type = varchar("type", 6)
    val amount = long("amount")
    val description = varchar("description", 255).nullable()
    val createdAt = timestampWithTimeZone("created_at").defaultExpression(CurrentTimestampWithTimeZone)

    override val primaryKey = PrimaryKey(id)
}

/** A bigint SQL fragment usable as a selectable, typed expression. */
private class RawLong(private val sql: String) : ExpressionWithColumnType<Long>() {
    override val columnType = LongColumnType()
    override fun toQueryBuilder(queryBuilder: QueryBuilder) {
        queryBuilder.append(sql)
    }
}

// Balance is always derived from the ledger: credits minus debits.
private const val SIGNED_AMOUNT = "CASE WHEN t.type = 'credit' THEN t.amount ELSE -t.amount END"

/** Current balance of the `accounts` row in scope, as a correlated subquery. */
val accountBalance: Expression<Long> =
    RawLong("COALESCE((SELECT SUM($SIGNED_AMOUNT) FROM transactions t WHERE t.account_id = accounts.id), 0)::bigint")

/** Sum of the selected `transactions` rows, for aggregate queries over that table. */
val ledgerBalance: Expression<Long> = RawLong(
    "COALESCE(SUM(CASE WHEN transactions.type = 'credit' THEN transactions.amount ELSE -transactions.amount END), 0)::bigint",
)

/** Number of transactions of the `accounts` row in scope. */
val accountTransactionCount: Expression<Long> =
    RawLong("(SELECT count(*) FROM transactions t WHERE t.account_id = accounts.id)")

fun connectDatabase(config: DbConfig): HikariDataSource {
    val dataSource = HikariDataSource(
        HikariConfig().apply {
            jdbcUrl = config.jdbcUrl
            username = config.user
            password = config.password
            maximumPoolSize = config.poolSize
            minimumIdle = config.poolSize
        },
    )
    Database.connect(dataSource)
    return dataSource
}

/** Runs [block] in a database transaction on the IO dispatcher (JDBC is blocking). */
suspend fun <T> dbQuery(block: suspend Transaction.() -> T): T =
    newSuspendedTransaction(Dispatchers.IO, statement = block)
