package controller

import (
	"net/http"
	"time"

	"github.com/devlopersabbir/devops-assessment/config"
	"github.com/gin-gonic/gin"
	"github.com/prometheus/client_golang/prometheus/promhttp"
)

type Handler struct {
	cfg *config.Config
}

func NewHandler(cfg *config.Config) *Handler {
	return &Handler{cfg: cfg}
}

// GetAppInfo handles GET / and returns application metadata.
func (h *Handler) GetAppInfo(c *gin.Context) {
	c.JSON(http.StatusOK, gin.H{
		"message": "Hello from DevOps Task!",
		"status":  "running",
		"version": h.cfg.AppVersion,
	})
}

// GetHealth handles GET /health and returns liveness/readiness status.
func (h *Handler) GetHealth(c *gin.Context) {
	c.JSON(http.StatusOK, gin.H{
		"status":    "UP",
		"liveness":  "OK",
		"readiness": "OK",
		"uptime":    time.Since(h.cfg.StartTime).Round(time.Second).String(),
		"timestamp": time.Now().UTC().Format(time.RFC3339),
	})
}

// GetMetrics handles GET /metrics and exposes Prometheus metrics.
func (h *Handler) GetMetrics() gin.HandlerFunc {
	return gin.WrapH(promhttp.Handler())
}

// NotFound handles unmatched routes.
func (h *Handler) NotFound(c *gin.Context) {
	c.JSON(http.StatusNotFound, gin.H{
		"error":  "Route not found",
		"path":   c.Request.URL.Path,
		"status": http.StatusNotFound,
	})
}
