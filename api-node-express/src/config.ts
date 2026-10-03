function env(key: string, fallback: string): string {
  const value = process.env[key];
  return value ? value : fallback;
}

function envInt(key: string, fallback: number): number {
  const value = Number.parseInt(process.env[key] ?? "", 10);
  return Number.isNaN(value) ? fallback : value;
}

export const config = {
  port: envInt("PORT", 8080),
  db: {
    host: env("DB_HOST", "localhost"),
    port: envInt("DB_PORT", 5432),
    database: env("DB_NAME", "apibattle"),
    username: env("DB_USER", "apibattle"),
    password: env("DB_PASSWORD", "apibattle"),
    poolSize: envInt("DB_POOL_SIZE", 10),
  },
};
