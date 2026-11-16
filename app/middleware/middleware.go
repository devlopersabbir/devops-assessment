package middleware

import (
	"encoding/json"
	"fmt"
	"net/http"
	"os"
	"strconv"
	"sync"
	"time"

	"github.com/devlopersabbir/devops-assessment/logger"
	"github.com/gin-gonic/gin"
	"github.com/prometheus/client_golang/prometheus"
)

var (
	registerOnce sync.Once

	httpRequestsTotal = prometheus.NewCounterVec(
		prometheus.CounterOpts{
			Name: "http_requests_total",
			Help: "Total number of HTTP requests processed, labeled by status code, method, and path.",
		},
		[]string{"method", "path", "status"},
	)

	httpErrorsTotal = prometheus.NewCounterVec(
		prometheus.CounterOpts{
			Name: "http_requests_errors_total",
			Help: "Total number of HTTP requests that resulted in 4xx or 5xx errors.",
		},
		[]string{"method", "path", "status"},
	)

	httpRequestDuration = prometheus.NewHistogramVec(
		prometheus.HistogramOpts{
			Name:    "http_request_duration_seconds",
			Help:    "Duration of HTTP requests in seconds.",
			Buckets: prometheus.DefBuckets,
		},
		[]string{"method", "path", "status"},
	)
)

func InitMetrics() {
	registerOnce.Do(func() {
		prometheus.MustRegister(httpRequestsTotal)
		prometheus.MustRegister(httpErrorsTotal)
		prometheus.MustRegister(httpRequestDuration)
	})
}

// RequestLogEntry represents a structured JSON log entry for HTTP requests.
type RequestLogEntry struct {
	Timestamp  string  `json:"timestamp"`
	Level      string  `json:"level"`
	Method     string  `json:"method"`
	Path       string  `json:"path"`
	StatusCode int     `json:"status"`
	LatencyMs  float64 `json:"latency_ms"`
	ClientIP   string  `json:"client_ip"`
	Message    string  `json:"message"`
}

// Logger logs incoming HTTP requests as structured JSON.
func Logger() gin.HandlerFunc {
	return func(c *gin.Context) {
		start := time.Now()
		path := c.Request.URL.Path
		raw := c.Request.URL.RawQuery

		c.Next()

		latency := time.Since(start)
		statusCode := c.Writer.Status()
		method := c.Request.Method
		clientIP := c.ClientIP()

		if raw != "" {
			path = path + "?" + raw
		}

		level := "INFO"
		if statusCode >= 500 {
			level = "ERROR"
		} else if statusCode >= 400 {
			level = "WARN"
		}

		entry := RequestLogEntry{
			Timestamp:  time.Now().UTC().Format(time.RFC3339Nano),
			Level:      level,
			Method:     method,
			Path:       path,
			StatusCode: statusCode,
			LatencyMs:  float64(latency.Nanoseconds()) / 1e6,
			ClientIP:   clientIP,
			Message:    fmt.Sprintf("%s %s | status=%d | latency=%v | ip=%s", method, path, statusCode, latency, clientIP),
		}

		data, err := json.Marshal(entry)
		if err != nil {
			logger.Errorf("Failed to marshal request log entry: %v", err)
			return
		}

		if level == "ERROR" {
			_, _ = fmt.Fprintln(os.Stderr, string(data))
		} else {
			_, _ = fmt.Fprintln(os.Stdout, string(data))
		}
	}
}

// Recovery recovers from panics and logs them with [ERROR] prefix.
func Recovery() gin.HandlerFunc {
	return func(c *gin.Context) {
		defer func() {
			if recovered := recover(); recovered != nil {
				logger.Errorf("Panic recovered on %s %s: %v", c.Request.Method, c.Request.URL.Path, recovered)
				c.AbortWithStatusJSON(http.StatusInternalServerError, gin.H{
					"error":  "Internal Server Error",
					"status": http.StatusInternalServerError,
				})
			}
		}()
		c.Next()
	}
}

// Prometheus records request counts and latency histograms.
func Prometheus() gin.HandlerFunc {
	InitMetrics()

	return func(c *gin.Context) {
		start := time.Now()

		c.Next()

		routePath := c.FullPath()
		if routePath == "" {
			routePath = c.Request.URL.Path
		}
		statusInt := c.Writer.Status()
		status := strconv.Itoa(statusInt)
		duration := time.Since(start).Seconds()

		httpRequestsTotal.WithLabelValues(c.Request.Method, routePath, status).Inc()
		if statusInt >= 400 {
			httpErrorsTotal.WithLabelValues(c.Request.Method, routePath, status).Inc()
		}
		httpRequestDuration.WithLabelValues(c.Request.Method, routePath, status).Observe(duration)
	}
}
