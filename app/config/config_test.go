package config

import (
	"os"
	"testing"
)

func TestLoadDefaults(t *testing.T) {
	keys := []string{"APP_NAME", "APP_VERSION", "APP_ENV", "LOG_LEVEL", "PORT"}
	saved := make(map[string]string)
	for _, k := range keys {
		saved[k] = os.Getenv(k)
		if err := os.Unsetenv(k); err != nil {
			t.Fatalf("failed to unset env %s: %v", k, err)
		}
	}
	defer func() {
		for k, v := range saved {
			if v != "" {
				if err := os.Setenv(k, v); err != nil {
					t.Errorf("failed to restore env %s: %v", k, err)
				}
			}
		}
	}()

	cfg := Load()

	if cfg.AppName != "devops-assessment-api" {
		t.Errorf("expected default AppName 'devops-assessment-api', got %q", cfg.AppName)
	}
	if cfg.AppVersion != "1.0.0" {
		t.Errorf("expected default AppVersion '1.0.0', got %q", cfg.AppVersion)
	}
	if cfg.AppEnv != "development" {
		t.Errorf("expected default AppEnv 'development', got %q", cfg.AppEnv)
	}
	if cfg.LogLevel != "info" {
		t.Errorf("expected default LogLevel 'info', got %q", cfg.LogLevel)
	}
	if cfg.Port != "8080" {
		t.Errorf("expected default Port '8080', got %q", cfg.Port)
	}
	if cfg.StartTime.IsZero() {
		t.Error("expected non-zero StartTime")
	}
}

func TestLoadFromEnv(t *testing.T) {
	t.Setenv("APP_NAME", "custom-api")
	t.Setenv("APP_VERSION", "2.3.4")
	t.Setenv("APP_ENV", "production")
	t.Setenv("LOG_LEVEL", "debug")
	t.Setenv("PORT", "9090")

	cfg := Load()

	if cfg.AppName != "custom-api" {
		t.Errorf("expected AppName 'custom-api', got %q", cfg.AppName)
	}
	if cfg.AppVersion != "2.3.4" {
		t.Errorf("expected AppVersion '2.3.4', got %q", cfg.AppVersion)
	}
	if cfg.AppEnv != "production" {
		t.Errorf("expected AppEnv 'production', got %q", cfg.AppEnv)
	}
	if cfg.LogLevel != "debug" {
		t.Errorf("expected LogLevel 'debug', got %q", cfg.LogLevel)
	}
	if cfg.Port != "9090" {
		t.Errorf("expected Port '9090', got %q", cfg.Port)
	}
}
