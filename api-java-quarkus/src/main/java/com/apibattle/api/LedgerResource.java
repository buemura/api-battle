package com.apibattle.api;

import com.fasterxml.jackson.core.JsonProcessingException;
import com.fasterxml.jackson.databind.JsonNode;
import com.fasterxml.jackson.databind.ObjectMapper;
import jakarta.ws.rs.GET;
import jakarta.ws.rs.POST;
import jakarta.ws.rs.Path;
import jakarta.ws.rs.PathParam;
import jakarta.ws.rs.Produces;
import jakarta.ws.rs.QueryParam;
import jakarta.ws.rs.core.MediaType;
import org.jboss.resteasy.reactive.ResponseStatus;

@Path("/")
@Produces(MediaType.APPLICATION_JSON)
public class LedgerResource {

    private static final int MAX_DESCRIPTION_LENGTH = 255;

    private final LedgerService ledger;
    private final ObjectMapper mapper;

    public LedgerResource(LedgerService ledger, ObjectMapper mapper) {
        this.ledger = ledger;
        this.mapper = mapper;
    }

    @GET
    @Path("health")
    @Produces(MediaType.TEXT_PLAIN)
    public String health() {
        return "ok";
    }

    @GET
    @Path("accounts")
    public PageResponse<AccountResponse> listAccounts(
            @QueryParam("page") String page, @QueryParam("page_size") String pageSize) {
        return ledger.listAccounts(Pagination.parse(page, pageSize));
    }

    @GET
    @Path("accounts/{id}")
    public AccountResponse getAccount(@PathParam("id") String id) {
        return ledger.getAccount(parseId(id));
    }

    @GET
    @Path("accounts/{id}/transactions")
    public PageResponse<TransactionResponse> listTransactions(
            @PathParam("id") String id, @QueryParam("page") String page, @QueryParam("page_size") String pageSize) {
        long accountId = parseId(id);
        return ledger.listTransactions(accountId, Pagination.parse(page, pageSize));
    }

    @POST
    @Path("accounts/{id}/transactions")
    @ResponseStatus(201)
    public TransactionResponse addTransaction(@PathParam("id") String id, String body) {
        long accountId = parseId(id);
        return ledger.addTransaction(accountId, parseNewTransaction(body));
    }

    @GET
    @Path("transactions/{id}")
    public TransactionResponse getTransaction(@PathParam("id") String id) {
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
            root = body == null || body.isBlank() ? null : mapper.readTree(body);
        } catch (JsonProcessingException e) {
            root = null;
        }
        if (root == null || !root.isObject()) {
            throw ApiException.badRequest("request body must be JSON");
        }

        JsonNode type = root.get("type");
        if (type == null || !type.isTextual()
                || !(type.textValue().equals("credit") || type.textValue().equals("debit"))) {
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
            String s = desc.isTextual() ? desc.textValue() : null;
            if (s == null || s.codePointCount(0, s.length()) > MAX_DESCRIPTION_LENGTH) {
                throw ApiException.badRequest("'description' must be a string of at most 255 characters");
            }
            description = s.isEmpty() ? null : s;
        }
        return new NewTransaction(type.textValue(), amount.longValue(), description);
    }
}
