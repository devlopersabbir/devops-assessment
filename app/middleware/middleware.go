package middleware

import (
	"fmt"
	"net/http"
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
		prometheus.MustRegister(httpRequestDuration)
	})
}

// Logger logs incoming HTTP requests with [INFO], [WARN], or [ERROR] prefixes.
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

		msg := fmt.Sprintf("%s %s | status=%d | latency=%v | ip=%s", method, path, statusCode, latency, clientIP)

		switch {
		case statusCode >= 500:
			logger.Error(msg)
		case statusCode >= 400:
			logger.Warn(msg)
		default:
			logger.Info(msg)
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
		status := strconv.Itoa(c.Writer.Status())
		duration := time.Since(start).Seconds()

		httpRequestsTotal.WithLabelValues(c.Request.Method, routePath, status).Inc()
		httpRequestDuration.WithLabelValues(c.Request.Method, routePath, status).Observe(duration)
	}
}
