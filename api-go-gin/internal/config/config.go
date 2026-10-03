package config

import (
	"fmt"
	"net/url"
	"os"
	"strconv"
)

type Config struct {
	Port       int
	DBHost     string
	DBPort     int
	DBName     string
	DBUser     string
	DBPassword string
	DBPoolSize int32
}

func Load() Config {
	return Config{
		Port:       envInt("PORT", 8080),
		DBHost:     env("DB_HOST", "localhost"),
		DBPort:     envInt("DB_PORT", 5432),
		DBName:     env("DB_NAME", "apibattle"),
		DBUser:     env("DB_USER", "apibattle"),
		DBPassword: env("DB_PASSWORD", "apibattle"),
		DBPoolSize: int32(envInt("DB_POOL_SIZE", 10)),
	}
}

func (c Config) DatabaseURL() string {
	u := url.URL{
		Scheme:   "postgres",
		User:     url.UserPassword(c.DBUser, c.DBPassword),
		Host:     fmt.Sprintf("%s:%d", c.DBHost, c.DBPort),
		Path:     c.DBName,
		RawQuery: "sslmode=disable",
	}
	return u.String()
}

func env(key, fallback string) string {
	if v := os.Getenv(key); v != "" {
		return v
	}
	return fallback
}

func envInt(key string, fallback int) int {
	if v, err := strconv.Atoi(os.Getenv(key)); err == nil {
		return v
	}
	return fallback
}
