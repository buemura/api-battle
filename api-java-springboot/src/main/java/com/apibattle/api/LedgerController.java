package com.apibattle.api;

import org.springframework.http.HttpStatus;
import org.springframework.web.bind.annotation.GetMapping;
import org.springframework.web.bind.annotation.PathVariable;
import org.springframework.web.bind.annotation.PostMapping;
import org.springframework.web.bind.annotation.RequestBody;
import org.springframework.web.bind.annotation.RequestParam;
import org.springframework.web.bind.annotation.ResponseStatus;
import org.springframework.web.bind.annotation.RestController;
import tools.jackson.core.JacksonException;
import tools.jackson.databind.JsonNode;
import tools.jackson.databind.ObjectMapper;

@RestController
public class LedgerController {

    private static final int MAX_DESCRIPTION_LENGTH = 255;

    private final LedgerService ledger;
    private final ObjectMapper mapper;

    public LedgerController(LedgerService ledger, ObjectMapper mapper) {
        this.ledger = ledger;
        this.mapper = mapper;
    }

    @GetMapping("/health")
    String health() {
        return "ok";
    }

    @GetMapping("/accounts")
    PageResponse<AccountResponse> listAccounts(
            @RequestParam(required = false) String page,
            @RequestParam(name = "page_size", required = false) String pageSize) {
        return ledger.listAccounts(Pagination.parse(page, pageSize));
    }

    @GetMapping("/accounts/{id}")
    AccountResponse getAccount(@PathVariable String id) {
        return ledger.getAccount(parseId(id));
    }

    @GetMapping("/accounts/{id}/transactions")
    PageResponse<TransactionResponse> listTransactions(
            @PathVariable String id,
            @RequestParam(required = false) String page,
            @RequestParam(name = "page_size", required = false) String pageSize) {
        long accountId = parseId(id);
        return ledger.listTransactions(accountId, Pagination.parse(page, pageSize));
    }

    @PostMapping("/accounts/{id}/transactions")
    @ResponseStatus(HttpStatus.CREATED)
    TransactionResponse addTransaction(@PathVariable String id, @RequestBody(required = false) String body) {
        long accountId = parseId(id);
        return ledger.addTransaction(accountId, parseNewTransaction(body));
    }

    @GetMapping("/transactions/{id}")
    TransactionResponse getTransaction(@PathVariable String id) {
        return ledger.getTransaction(parseId(id));
    }

    // Non-numeric ids can never match a resource, so they are reported as 404.
    private static long parseId(String raw) {
        try {
            return Long.parseLong(raw);
        } catch (NumberFormatException e) {
            throw ApiException.notFound("not found");
        }
    }

    // Validates field by field so each problem gets a specific message.
    private NewTransaction parseNewTransaction(String body) {
        JsonNode root;
        try {
            root = body == null ? null : mapper.readTree(body);
        } catch (JacksonException e) {
            root = null;
        }
        if (root == null || !root.isObject()) {
            throw ApiException.badRequest("request body must be JSON");
        }

        JsonNode type = root.get("type");
        if (type == null || !type.isString()
                || !(type.stringValue().equals("credit") || type.stringValue().equals("debit"))) {
            throw ApiException.badRequest("'type' must be either 'credit' or 'debit'");
        }

        // Only integral JSON numbers are accepted, so 10.5 is rejected rather than truncated.
        JsonNode amount = root.get("amount");
        if (amount == null || !amount.isIntegralNumber() || !amount.canConvertToLong() || amount.longValue() <= 0) {
            throw ApiException.badRequest("'amount' must be a positive integer (minor units, e.g. cents)");
        }

        String description = null;
        JsonNode desc = root.get("description");
        if (desc != null && !desc.isNull()) {
            String s = desc.isString() ? desc.stringValue() : null;
            if (s == null || s.codePointCount(0, s.length()) > MAX_DESCRIPTION_LENGTH) {
                throw ApiException.badRequest("'description' must be a string of at most 255 characters");
            }
            description = s.isEmpty() ? null : s;
        }
        return new NewTransaction(type.stringValue(), amount.longValue(), description);
    }
}
