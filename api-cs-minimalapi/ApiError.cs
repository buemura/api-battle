namespace ApiBattleApi;

/// Every non-2xx response is rendered as `{"error": "<message>"}`.
public static class ApiError
{
    public static IResult BadRequest(string message) =>
        TypedResults.BadRequest(new ErrorResponse(message));

    public static IResult NotFound(string message) =>
        TypedResults.NotFound(new ErrorResponse(message));

    public static IResult Unprocessable(string message) =>
        TypedResults.UnprocessableEntity(new ErrorResponse(message));
}
