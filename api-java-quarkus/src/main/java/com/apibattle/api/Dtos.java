package com.apibattle.api;

import com.fasterxml.jackson.annotation.JsonFormat;
import java.time.Instant;
import java.util.List;

// ISO-8601 UTC with millisecond precision, e.g. "2026-10-03T02:44:35.274Z".
final class Json {
    static final String TIMESTAMP = "yyyy-MM-dd'T'HH:mm:ss.SSS'Z'";

    private Json() {}
}

record AccountResponse(
        long id,
        String name,
        long balance,
        @JsonFormat(pattern = Json.TIMESTAMP, timezone = "UTC") Instant createdAt) {}

record TransactionResponse(
        long id,
        long accountId,
        String type,
        long amount,
        String description,
        @JsonFormat(pattern = Json.TIMESTAMP, timezone = "UTC") Instant createdAt) {

    static TransactionResponse from(Transaction t) {
        return new TransactionResponse(t.id, t.accountId, t.type, t.amount, t.description, t.createdAt);
    }
}

record PageResponse<T>(List<T> data, int page, int pageSize, long total) {}

record NewTransaction(String type, long amount, String description) {}

record ErrorResponse(String error) {}
