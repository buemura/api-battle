namespace ApiBattleApi;

public readonly record struct Pagination(int Page, int PageSize)
{
    private const int DefaultPageSize = 20;
    private const int MaxPageSize = 100;

    public const string InvalidMessage = "'page' must be >= 1 and 'page_size' must be between 1 and 100";

    public int Offset => (Page - 1) * PageSize;

    // Parsed from raw strings so malformed values get our JSON error instead
    // of the framework's default binding failure.
    public static bool TryParse(HttpRequest request, out Pagination pagination)
    {
        pagination = default;
        if (!TryParsePositive(request.Query["page"], 1, out var page)) return false;
        if (!TryParsePositive(request.Query["page_size"], DefaultPageSize, out var pageSize)) return false;
        if (pageSize > MaxPageSize) return false;

        pagination = new Pagination(page, pageSize);
        return true;
    }

    private static bool TryParsePositive(string? raw, int fallback, out int value)
    {
        if (string.IsNullOrEmpty(raw))
        {
            value = fallback;
            return true;
        }
        return int.TryParse(raw, System.Globalization.NumberStyles.None, null, out value) && value >= 1;
    }
}
