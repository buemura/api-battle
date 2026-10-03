package com.apibattle

import io.ktor.http.HttpStatusCode
import kotlinx.serialization.json.Json
import kotlinx.serialization.json.JsonNull
import kotlinx.serialization.json.JsonObject
import kotlinx.serialization.json.JsonPrimitive
import kotlinx.serialization.json.longOrNull

/** An expected failure, rendered as `{"error": "<message>"}`. */
class ApiException(val status: HttpStatusCode, message: String) : RuntimeException(message)

fun badRequest(message: String) = ApiException(HttpStatusCode.BadRequest, message)
fun notFound(message: String) = ApiException(HttpStatusCode.NotFound, message)
fun unprocessable(message: String) = ApiException(HttpStatusCode.UnprocessableEntity, message)

private const val DEFAULT_PAGE_SIZE = 20
private const val MAX_PAGE_SIZE = 100
private const val MAX_DESCRIPTION_LENGTH = 255

data class Pagination(val page: Int, val pageSize: Int) {
    val limit get() = pageSize
    val offset get() = (page - 1).toLong() * pageSize

    companion object {
        // Missing or empty values fall back to the default; anything else must be
        // a plain positive integer within range.
        fun parse(page: String?, pageSize: String?): Pagination {
            val p = parsePositive(page, 1)
            val size = parsePositive(pageSize, DEFAULT_PAGE_SIZE)
            if (p < 1 || size < 1 || size > MAX_PAGE_SIZE) {
                throw badRequest("'page' must be >= 1 and 'page_size' must be between 1 and 100")
            }
            return Pagination(p, size)
        }

        private fun parsePositive(raw: String?, fallback: Int): Int =
            if (raw.isNullOrEmpty()) fallback else raw.toIntOrNull() ?: -1
    }
}

/**
 * Numeric path id. Non-numeric ids can never match a resource, so they are
 * reported as 404 rather than 400.
 */
fun parseId(raw: String?): Long = raw?.toLongOrNull() ?: throw notFound("not found")

private const val TYPE_ERROR = "'type' must be either 'credit' or 'debit'"
private const val AMOUNT_ERROR = "'amount' must be a positive integer (minor units, e.g. cents)"
private const val DESCRIPTION_ERROR = "'description' must be a string of at most $MAX_DESCRIPTION_LENGTH characters"

/** Validates field by field; the first invalid field determines the message. */
fun parseNewTransaction(body: String): NewTransaction {
    val element = try {
        Json.parseToJsonElement(body)
    } catch (e: Exception) {
        throw badRequest("request body must be JSON")
    }
    val obj = element as? JsonObject ?: throw badRequest("request body must be a JSON object")

    val type = (obj["type"] as? JsonPrimitive)
        ?.takeIf { it.isString && (it.content == "credit" || it.content == "debit") }
        ?.content
        ?: throw badRequest(TYPE_ERROR)

    val amount = (obj["amount"] as? JsonPrimitive)
        ?.takeIf { !it.isString }
        ?.longOrNull
        ?.takeIf { it > 0 }
        ?: throw badRequest(AMOUNT_ERROR)

    val description = when (val raw = obj["description"]) {
        null, JsonNull -> null
        is JsonPrimitive -> {
            // Count code points, not UTF-16 units, to match the VARCHAR limit.
            if (!raw.isString || raw.content.codePointCount(0, raw.content.length) > MAX_DESCRIPTION_LENGTH) {
                throw badRequest(DESCRIPTION_ERROR)
            }
            raw.content.ifEmpty { null }
        }
        else -> throw badRequest(DESCRIPTION_ERROR)
    }

    return NewTransaction(type, amount, description)
}
