# ---- build stage ----
FROM golang:1.25-alpine AS build
WORKDIR /src
COPY go.mod go.sum ./
RUN go mod download
COPY . .
RUN CGO_ENABLED=0 go build -trimpath -ldflags="-s -w" -o /out/apibattle_api ./cmd/api

# ---- runtime stage ----
FROM alpine:3.22
RUN apk add --no-cache curl && adduser -S -H app
COPY --from=build /out/apibattle_api /usr/local/bin/apibattle_api
USER app
EXPOSE 8080
HEALTHCHECK --interval=10s --timeout=3s --retries=3 CMD curl -fsS http://localhost:8080/health || exit 1
ENTRYPOINT ["/usr/local/bin/apibattle_api"]
