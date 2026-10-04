# ---- dependencies ----
FROM dunglas/frankenphp:1-php8.5-alpine AS base
RUN install-php-extensions pdo_pgsql pcntl opcache \
 && cp "$PHP_INI_DIR/php.ini-production" "$PHP_INI_DIR/php.ini"
COPY docker/php.ini "$PHP_INI_DIR/conf.d/zz-app.ini"
WORKDIR /app

FROM base AS deps
COPY --from=composer:2 /usr/bin/composer /usr/bin/composer
COPY composer.json composer.lock ./
RUN composer install --no-dev --no-scripts --no-autoloader --no-interaction --prefer-dist
COPY . .
RUN composer dump-autoload --no-dev --classmap-authoritative \
 && php artisan package:discover --ansi

# ---- runtime ----
FROM base
ENV APP_ENV=production \
    APP_DEBUG=false \
    LOG_CHANNEL=stderr \
    LOG_LEVEL=warning \
    DB_CONNECTION=pgsql \
    CACHE_STORE=array \
    SESSION_DRIVER=array \
    QUEUE_CONNECTION=sync
RUN adduser -D -H app
COPY --from=deps --chown=app:app /app /app
RUN chown -R app:app /data/caddy /config/caddy
USER app
EXPOSE 8080
HEALTHCHECK --interval=10s --timeout=3s --start-period=10s --retries=3 CMD wget -qO- http://localhost:8080/health || exit 1
ENTRYPOINT ["/app/docker-entrypoint.sh"]
