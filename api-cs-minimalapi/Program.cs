using System.Text.Json;
using System.Text.Json.Serialization;
using Microsoft.AspNetCore.Diagnostics;
using Microsoft.EntityFrameworkCore;
using Npgsql;
using ApiBattleApi;
using ApiBattleApi.Data;

var builder = WebApplication.CreateSlimBuilder(args);

string Env(string key, string fallback) =>
    Environment.GetEnvironmentVariable(key) is { Length: > 0 } value ? value : fallback;

int EnvInt(string key, int fallback) =>
    int.TryParse(Environment.GetEnvironmentVariable(key), out var value) ? value : fallback;

var port = EnvInt("PORT", 8080);
// Dual-stack (IPv4 + IPv6) so `localhost` works whichever it resolves to.
builder.WebHost.ConfigureKestrel(kestrel => kestrel.ListenAnyIP(port));

var connectionString = new NpgsqlConnectionStringBuilder
{
    Host = Env("DB_HOST", "localhost"),
    Port = EnvInt("DB_PORT", 5432),
    Database = Env("DB_NAME", "apibattle"),
    Username = Env("DB_USER", "apibattle"),
    Password = Env("DB_PASSWORD", "apibattle"),
    MaxPoolSize = EnvInt("DB_POOL_SIZE", 10),
    Timeout = 5,
}.ConnectionString;

builder.Services.AddDbContextPool<ApiBattleDbContext>(options => options
    .UseNpgsql(connectionString)
    .UseQueryTrackingBehavior(QueryTrackingBehavior.NoTracking));

builder.Services.ConfigureHttpJsonOptions(options =>
{
    var json = options.SerializerOptions;
    json.PropertyNamingPolicy = JsonNamingPolicy.SnakeCaseLower;
    json.Converters.Add(new JsonStringEnumConverter(JsonNamingPolicy.SnakeCaseLower));
    json.Converters.Add(new IsoMillisDateTimeConverter());
});

builder.Services.AddRequestTimeouts(options =>
{
    options.DefaultPolicy = new()
    {
        Timeout = TimeSpan.FromSeconds(10),
        TimeoutStatusCode = StatusCodes.Status408RequestTimeout,
    };
});

var app = builder.Build();

app.UseExceptionHandler(errorApp => errorApp.Run(async context =>
{
    var error = context.Features.Get<IExceptionHandlerFeature>()?.Error;
    app.Logger.LogError(error, "unhandled error");
    context.Response.StatusCode = StatusCodes.Status500InternalServerError;
    await context.Response.WriteAsJsonAsync(new ErrorResponse("internal server error"));
}));
app.UseRequestTimeouts();

app.MapApiBattleEndpoints();
app.MapDocs();

app.Run();
