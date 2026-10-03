using System.Text.Json;
using System.Text.Json.Serialization;
using ApiBattleApi.Data;

namespace ApiBattleApi;

public record AccountResponse(long Id, string Name, long Balance, DateTime CreatedAt);

public record TransactionResponse(
    long Id,
    long AccountId,
    TransactionType Type,
    long Amount,
    string? Description,
    DateTime CreatedAt)
{
    public static TransactionResponse From(Transaction t) =>
        new(t.Id, t.AccountId, t.Type, t.Amount, t.Description, t.CreatedAt);
}

public record PageResponse<T>(IReadOnlyList<T> Data, int Page, int PageSize, long Total);

public record ErrorResponse(string Error);

/// Renders timestamps as ISO-8601 UTC with millisecond precision,
/// e.g. `2026-10-03T02:44:35.274Z`.
public class IsoMillisDateTimeConverter : JsonConverter<DateTime>
{
    public override DateTime Read(ref Utf8JsonReader reader, Type typeToConvert, JsonSerializerOptions options) =>
        reader.GetDateTime().ToUniversalTime();

    public override void Write(Utf8JsonWriter writer, DateTime value, JsonSerializerOptions options) =>
        writer.WriteStringValue(value.ToUniversalTime().ToString("yyyy-MM-dd'T'HH:mm:ss.fff'Z'"));
}
