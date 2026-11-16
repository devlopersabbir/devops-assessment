package main

import (
	"encoding/json"
	"net/http"
	"net/http/httptest"
	"strings"
	"testing"
	"time"

	"github.com/devlopersabbir/devops-assessment/config"
	"github.com/devlopersabbir/devops-assessment/middleware"
	"github.com/devlopersabbir/devops-assessment/router"
	"github.com/gin-gonic/gin"
)

func newTestConfig() *config.Config {
	return &config.Config{
		AppName:    "devops-assessment-api",
		AppVersion: "1.0.0",
		AppEnv:     "test",
		LogLevel:   "info",
		Port:       "8080",
		StartTime:  time.Now().Add(-5 * time.Second),
	}
}

func TestRootEndpoint(t *testing.T) {
	cfg := newTestConfig()
	r := router.Setup(cfg)

	req, err := http.NewRequest(http.MethodGet, "/", nil)
	if err != nil {
		t.Fatalf("failed to create request: %v", err)
	}
	w := httptest.NewRecorder()
	r.ServeHTTP(w, req)

	if w.Code != http.StatusOK {
		t.Fatalf("expected status %d, got %d", http.StatusOK, w.Code)
	}

	contentType := w.Header().Get("Content-Type")
	if !strings.Contains(contentType, "application/json") {
		t.Errorf("expected Content-Type application/json, got %q", contentType)
	}

	var body map[string]interface{}
	if err := json.Unmarshal(w.Body.Bytes(), &body); err != nil {
		t.Fatalf("failed to parse JSON response: %v", err)
	}

	expectedFields := []string{
		"message",
		"status",
		"version",
	}
	for _, field := range expectedFields {
		if val, ok := body[field]; !ok || val == "" {
			t.Errorf("expected non-empty field %q in root response, got %v", field, val)
		}
	}

	if body["message"] != "Hello from DevOps Task!" {
		t.Errorf("expected message 'Hello from DevOps Task!', got %v", body["message"])
	}
	if body["status"] != "running" {
		t.Errorf("expected status 'running', got %v", body["status"])
	}
	if body["version"] != cfg.AppVersion {
		t.Errorf("expected version %q, got %v", cfg.AppVersion, body["version"])
	}
}

func TestHealthEndpoint(t *testing.T) {
	cfg := newTestConfig()
	r := router.Setup(cfg)

	req, err := http.NewRequest(http.MethodGet, "/health", nil)
	if err != nil {
		t.Fatalf("failed to create request: %v", err)
	}
	w := httptest.NewRecorder()
	r.ServeHTTP(w, req)

	if w.Code != http.StatusOK {
		t.Fatalf("expected status %d, got %d", http.StatusOK, w.Code)
	}

	var body map[string]interface{}
	if err := json.Unmarshal(w.Body.Bytes(), &body); err != nil {
		t.Fatalf("failed to parse JSON response: %v", err)
	}

	if body["status"] != "UP" {
		t.Errorf("expected status UP, got %v", body["status"])
	}
	if body["liveness"] != "OK" {
		t.Errorf("expected liveness OK, got %v", body["liveness"])
	}
	if body["readiness"] != "OK" {
		t.Errorf("expected readiness OK, got %v", body["readiness"])
	}
	if _, ok := body["uptime"]; !ok {
		t.Error("expected uptime field in health response")
	}
	if _, ok := body["timestamp"]; !ok {
		t.Error("expected timestamp field in health response")
	}
}

func TestMetricsEndpoint(t *testing.T) {
	cfg := newTestConfig()
	r := router.Setup(cfg)

	// Send initial requests so custom Prometheus metrics are recorded
	for _, path := range []string{"/", "/health", "/non-existent"} {
		req, _ := http.NewRequest(http.MethodGet, path, nil)
		r.ServeHTTP(httptest.NewRecorder(), req)
	}

	req, err := http.NewRequest(http.MethodGet, "/metrics", nil)
	if err != nil {
		t.Fatalf("failed to create request: %v", err)
	}
	w := httptest.NewRecorder()
	r.ServeHTTP(w, req)

	if w.Code != http.StatusOK {
		t.Fatalf("expected status %d, got %d", http.StatusOK, w.Code)
	}

	output := w.Body.String()
	expectedMetrics := []string{
		"http_requests_total",
		"http_requests_errors_total",
		"http_request_duration_seconds",
		"go_goroutines",
	}
	for _, metric := range expectedMetrics {
		if !strings.Contains(output, metric) {
			t.Errorf("expected /metrics output to contain %q", metric)
		}
	}
}

func TestNotFoundEndpoint(t *testing.T) {
	cfg := newTestConfig()
	r := router.Setup(cfg)

	req, err := http.NewRequest(http.MethodGet, "/non-existent-route?foo=bar", nil)
	if err != nil {
		t.Fatalf("failed to create request: %v", err)
	}
	w := httptest.NewRecorder()
	r.ServeHTTP(w, req)

	if w.Code != http.StatusNotFound {
		t.Fatalf("expected status %d, got %d", http.StatusNotFound, w.Code)
	}

	var body map[string]interface{}
	if err := json.Unmarshal(w.Body.Bytes(), &body); err != nil {
		t.Fatalf("failed to parse JSON response: %v", err)
	}

	if body["error"] != "Route not found" {
		t.Errorf("expected error 'Route not found', got %v", body["error"])
	}
	if body["path"] != "/non-existent-route" {
		t.Errorf("expected path '/non-existent-route', got %v", body["path"])
	}
}

func TestRecoveryMiddleware(t *testing.T) {
	gin.SetMode(gin.ReleaseMode)
	r := gin.New()
	r.Use(middleware.Logger())
	r.Use(middleware.Recovery())

	r.GET("/panic", func(c *gin.Context) {
		panic("simulated unexpected panic")
	})

	req, err := http.NewRequest(http.MethodGet, "/panic", nil)
	if err != nil {
		t.Fatalf("failed to create request: %v", err)
	}
	w := httptest.NewRecorder()
	r.ServeHTTP(w, req)

	if w.Code != http.StatusInternalServerError {
		t.Fatalf("expected status %d after panic recovery, got %d", http.StatusInternalServerError, w.Code)
	}

	var body map[string]interface{}
	if err := json.Unmarshal(w.Body.Bytes(), &body); err != nil {
		t.Fatalf("failed to parse JSON response: %v", err)
	}

	if body["error"] != "Internal Server Error" {
		t.Errorf("expected error 'Internal Server Error', got %v", body["error"])
	}
}
