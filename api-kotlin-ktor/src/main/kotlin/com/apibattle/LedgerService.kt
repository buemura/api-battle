package com.apibattle

import org.jetbrains.exposed.sql.ResultRow
import org.jetbrains.exposed.sql.SortOrder
import org.jetbrains.exposed.sql.SqlExpressionBuilder.eq
import org.jetbrains.exposed.sql.insertReturning
import org.jetbrains.exposed.sql.selectAll

object LedgerService {

    private val accountColumns = listOf(Accounts.id, Accounts.name, accountBalance, Accounts.createdAt)

    private fun ResultRow.toAccount() = AccountResponse(
        id = this[Accounts.id],
        name = this[Accounts.name],
        balance = this[accountBalance],
        createdAt = this[Accounts.createdAt].toJson(),
    )

    private fun ResultRow.toTransaction() = TransactionResponse(
        id = this[Transactions.id],
        accountId = this[Transactions.accountId],
        type = this[Transactions.type],
        amount = this[Transactions.amount],
        description = this[Transactions.description],
        createdAt = this[Transactions.createdAt].toJson(),
    )

    suspend fun listAccounts(p: Pagination): PageResponse<AccountResponse> = dbQuery {
        val total = Accounts.selectAll().count()
        val data = Accounts.select(accountColumns)
            .orderBy(Accounts.id)
            .limit(p.limit)
            .offset(p.offset)
            .map { it.toAccount() }
        PageResponse(data, p.page, p.pageSize, total)
    }

    suspend fun getAccount(id: Long): AccountResponse = dbQuery {
        Accounts.select(accountColumns)
            .where { Accounts.id eq id }
            .singleOrNull()
            ?.toAccount()
            ?: throw notFound("account not found")
    }

    suspend fun listTransactions(accountId: Long, p: Pagination): PageResponse<TransactionResponse> = dbQuery {
        val total = Accounts.select(accountTransactionCount)
            .where { Accounts.id eq accountId }
            .singleOrNull()
            ?.get(accountTransactionCount)
            ?: throw notFound("account not found")

        val data = Transactions.selectAll()
            .where { Transactions.accountId eq accountId }
            .orderBy(Transactions.id, SortOrder.DESC)
            .limit(p.limit)
            .offset(p.offset)
            .map { it.toTransaction() }
        PageResponse(data, p.page, p.pageSize, total)
    }

    suspend fun addTransaction(accountId: Long, input: NewTransaction): TransactionResponse = dbQuery {
        // Lock the account row so concurrent debits can't overdraw it.
        Accounts.select(Accounts.id)
            .where { Accounts.id eq accountId }
            .forUpdate()
            .singleOrNull()
            ?: throw notFound("account not found")

        if (input.type == "debit") {
            val balance = Transactions.select(ledgerBalance)
                .where { Transactions.accountId eq accountId }
                .single()[ledgerBalance]
            if (balance < input.amount) throw unprocessable("insufficient funds")
        }

        Transactions.insertReturning {
            it[Transactions.accountId] = accountId
            it[type] = input.type
            it[amount] = input.amount
            it[description] = input.description
        }.single().toTransaction()
    }

    suspend fun getTransaction(id: Long): TransactionResponse = dbQuery {
        Transactions.selectAll()
            .where { Transactions.id eq id }
            .singleOrNull()
            ?.toTransaction()
            ?: throw notFound("transaction not found")
    }
}
