# ---- build stage ----
FROM mcr.microsoft.com/dotnet/sdk:10.0-alpine AS build
WORKDIR /src

# Cache package restore separately from the application source.
COPY ApiBattleApi.csproj ./
RUN dotnet restore

COPY . ./
RUN dotnet publish -c Release --no-restore -o /app

# ---- runtime stage ----
FROM mcr.microsoft.com/dotnet/aspnet:10.0-alpine
WORKDIR /app
COPY --from=build /app ./
USER $APP_UID
EXPOSE 8080
HEALTHCHECK --interval=10s --timeout=3s --retries=3 CMD wget -qO- http://localhost:8080/health || exit 1
ENTRYPOINT ["dotnet", "ApiBattleApi.dll"]
