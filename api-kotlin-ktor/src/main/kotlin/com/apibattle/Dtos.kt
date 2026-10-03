package com.apibattle

import java.time.OffsetDateTime
import java.time.ZoneOffset
import java.time.format.DateTimeFormatter
import kotlinx.serialization.SerialName
import kotlinx.serialization.Serializable

// ISO-8601 UTC with millisecond precision, e.g. "2026-10-03T02:44:35.274Z".
private val TIMESTAMP = DateTimeFormatter.ofPattern("yyyy-MM-dd'T'HH:mm:ss.SSS'Z'").withZone(ZoneOffset.UTC)

fun OffsetDateTime.toJson(): String = TIMESTAMP.format(this)

@Serializable
data class AccountResponse(
    val id: Long,
    val name: String,
    val balance: Long,
    @SerialName("created_at") val createdAt: String,
)

@Serializable
data class TransactionResponse(
    val id: Long,
    @SerialName("account_id") val accountId: Long,
    val type: String,
    val amount: Long,
    val description: String?,
    @SerialName("created_at") val createdAt: String,
)

@Serializable
data class PageResponse<T>(
    val data: List<T>,
    val page: Int,
    @SerialName("page_size") val pageSize: Int,
    val total: Long,
)

@Serializable
data class ErrorResponse(val error: String)

data class NewTransaction(val type: String, val amount: Long, val description: String?)
