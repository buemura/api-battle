using System.Linq.Expressions;
using System.Text.Json;
using Microsoft.EntityFrameworkCore;
using ApiBattleApi.Data;

namespace ApiBattleApi;

public static class Endpoints
{
    private const int MaxDescriptionLength = 255;

    /// Accounts with their balance derived from the ledger.
    private static readonly Expression<Func<Account, AccountResponse>> ToAccountResponse = a => new AccountResponse(
        a.Id,
        a.Name,
        a.Transactions.Sum(t => t.Type == TransactionType.Credit ? t.Amount : -t.Amount),
        a.CreatedAt);

    public static void MapApiBattleEndpoints(this IEndpointRouteBuilder app)
    {
        app.MapGet("/health", () => TypedResults.Text("ok"));
        app.MapGet("/accounts", ListAccounts);
        app.MapGet("/accounts/{id}", GetAccount);
        app.MapGet("/accounts/{id}/transactions", ListTransactions);
        app.MapPost("/accounts/{id}/transactions", AddTransaction);
        app.MapGet("/transactions/{id}", GetTransaction);
    }

    // Path ids are bound as strings: non-numeric ids can never match a
    // resource, so they are reported as 404 with our JSON error body.
    private static bool TryParseId(string raw, out long id) =>
        long.TryParse(raw, System.Globalization.NumberStyles.AllowLeadingSign, null, out id);

    private static async Task<IResult> ListAccounts(HttpRequest request, ApiBattleDbContext db, CancellationToken ct)
    {
        if (!Pagination.TryParse(request, out var p)) return ApiError.BadRequest(Pagination.InvalidMessage);

        var total = await db.Accounts.LongCountAsync(ct);
        var data = await db.Accounts
            .OrderBy(a => a.Id)
            .Skip(p.Offset)
            .Take(p.PageSize)
            .Select(ToAccountResponse)
            .ToListAsync(ct);

        return TypedResults.Ok(new PageResponse<AccountResponse>(data, p.Page, p.PageSize, total));
    }

    private static async Task<IResult> GetAccount(string id, ApiBattleDbContext db, CancellationToken ct)
    {
        if (!TryParseId(id, out var accountId)) return ApiError.NotFound("account not found");

        var account = await db.Accounts
            .Where(a => a.Id == accountId)
            .Select(ToAccountResponse)
            .FirstOrDefaultAsync(ct);

        return account is null ? ApiError.NotFound("account not found") : TypedResults.Ok(account);
    }

    private static async Task<IResult> ListTransactions(
        string id, HttpRequest request, ApiBattleDbContext db, CancellationToken ct)
    {
        if (!TryParseId(id, out var accountId)) return ApiError.NotFound("account not found");
        if (!Pagination.TryParse(request, out var p)) return ApiError.BadRequest(Pagination.InvalidMessage);

        // Null when the account doesn't exist, so one query covers both checks.
        var total = await db.Accounts
            .Where(a => a.Id == accountId)
            .Select(a => (long?)a.Transactions.LongCount())
            .FirstOrDefaultAsync(ct);
        if (total is null) return ApiError.NotFound("account not found");

        var data = await db.Transactions
            .Where(t => t.AccountId == accountId)
            .OrderByDescending(t => t.Id)
            .Skip(p.Offset)
            .Take(p.PageSize)
            .Select(t => new TransactionResponse(t.Id, t.AccountId, t.Type, t.Amount, t.Description, t.CreatedAt))
            .ToListAsync(ct);

        return TypedResults.Ok(new PageResponse<TransactionResponse>(data, p.Page, p.PageSize, total.Value));
    }

    private static async Task<IResult> AddTransaction(
        string id, HttpRequest request, ApiBattleDbContext db, CancellationToken ct)
    {
        if (!TryParseId(id, out var accountId)) return ApiError.NotFound("account not found");

        JsonDocument body;
        try
        {
            if (!request.HasJsonContentType()) throw new JsonException();
            body = await JsonDocument.ParseAsync(request.Body, cancellationToken: ct);
        }
        catch (JsonException)
        {
            return ApiError.BadRequest("request body must be JSON");
        }

        using (body)
        {
            if (!TryParseNewTransaction(body.RootElement, out var newTx, out var error))
                return ApiError.BadRequest(error);

            await using var tx = await db.Database.BeginTransactionAsync(ct);

            // Lock the account row so concurrent debits can't overdraw it.
            var locked = await db.Database
                .SqlQuery<long>($"SELECT id AS \"Value\" FROM accounts WHERE id = {accountId} FOR UPDATE")
                .ToListAsync(ct);
            if (locked.Count == 0) return ApiError.NotFound("account not found");

            if (newTx.Type == TransactionType.Debit)
            {
                var balance = await db.Transactions
                    .Where(t => t.AccountId == accountId)
                    .SumAsync(t => t.Type == TransactionType.Credit ? t.Amount : -t.Amount, ct);
                if (balance < newTx.Amount) return ApiError.Unprocessable("insufficient funds");
            }

            newTx.AccountId = accountId;
            db.Transactions.Add(newTx);
            await db.SaveChangesAsync(ct);
            await tx.CommitAsync(ct);

            return TypedResults.Created($"/transactions/{newTx.Id}", TransactionResponse.From(newTx));
        }
    }

    // Validated field by field so each problem gets a specific message.
    private static bool TryParseNewTransaction(JsonElement body, out Transaction transaction, out string error)
    {
        transaction = new Transaction();
        error = "";

        if (body.ValueKind != JsonValueKind.Object)
        {
            error = "request body must be a JSON object";
            return false;
        }

        var type = body.TryGetProperty("type", out var typeEl) && typeEl.ValueKind == JsonValueKind.String
            ? typeEl.GetString()
            : null;
        switch (type)
        {
            case "credit": transaction.Type = TransactionType.Credit; break;
            case "debit": transaction.Type = TransactionType.Debit; break;
            default:
                error = "'type' must be either 'credit' or 'debit'";
                return false;
        }

        if (!body.TryGetProperty("amount", out var amountEl)
            || amountEl.ValueKind != JsonValueKind.Number
            || !amountEl.TryGetInt64(out var amount)
            || amount <= 0)
        {
            error = "'amount' must be a positive integer (minor units, e.g. cents)";
            return false;
        }
        transaction.Amount = amount;

        if (body.TryGetProperty("description", out var descEl) && descEl.ValueKind != JsonValueKind.Null)
        {
            // Postgres varchar limits count characters (code points), not UTF-16 units.
            var description = descEl.ValueKind == JsonValueKind.String ? descEl.GetString()! : null;
            if (description is null || description.EnumerateRunes().Count() > MaxDescriptionLength)
            {
                error = "'description' must be a string of at most 255 characters";
                return false;
            }
            transaction.Description = description.Length == 0 ? null : description;
        }

        return true;
    }

    private static async Task<IResult> GetTransaction(string id, ApiBattleDbContext db, CancellationToken ct)
    {
        if (!TryParseId(id, out var transactionId)) return ApiError.NotFound("transaction not found");

        var transaction = await db.Transactions
            .Where(t => t.Id == transactionId)
            .Select(t => new TransactionResponse(t.Id, t.AccountId, t.Type, t.Amount, t.Description, t.CreatedAt))
            .FirstOrDefaultAsync(ct);

        return transaction is null ? ApiError.NotFound("transaction not found") : TypedResults.Ok(transaction);
    }
}
