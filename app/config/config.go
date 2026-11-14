package config

import (
	"os"
	"time"
)

type Config struct {
	AppName    string
	AppVersion string
	AppEnv     string
	LogLevel   string
	Port       string
	StartTime  time.Time
}

func Load() *Config {
	return &Config{
		AppName:    getEnv("APP_NAME", "devops-assessment-api"),
		AppVersion: getEnv("APP_VERSION", "1.0.0"),
		AppEnv:     getEnv("APP_ENV", "development"),
		LogLevel:   getEnv("LOG_LEVEL", "info"),
		Port:       getEnv("PORT", "8080"),
		StartTime:  time.Now(),
	}
}

func getEnv(key, fallback string) string {
	if value, exists := os.LookupEnv(key); exists && value != "" {
		return value
	}
	return fallback
}
