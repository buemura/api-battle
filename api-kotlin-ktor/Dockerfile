# ---- build stage ----
FROM gradle:8.14-jdk21-alpine AS build
WORKDIR /src
COPY settings.gradle.kts build.gradle.kts ./
RUN gradle --no-daemon -q dependencies > /dev/null
COPY src ./src
RUN gradle --no-daemon -q buildFatJar

# ---- runtime stage ----
FROM eclipse-temurin:21-jre-alpine
RUN apk add --no-cache curl && adduser -S -H app
COPY --from=build /src/build/libs/app.jar /app/app.jar
USER app
EXPOSE 8080
HEALTHCHECK --interval=10s --timeout=3s --start-period=20s --retries=3 CMD curl -fsS http://localhost:8080/health || exit 1
ENTRYPOINT ["java", "-XX:MaxRAMPercentage=75", "-jar", "/app/app.jar"]
