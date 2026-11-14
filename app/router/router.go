package router

import (
	"github.com/devlopersabbir/devops-assessment/config"
	"github.com/devlopersabbir/devops-assessment/controller"
	"github.com/devlopersabbir/devops-assessment/middleware"
	"github.com/gin-gonic/gin"
)

func Setup(cfg *config.Config) *gin.Engine {
	gin.SetMode(gin.ReleaseMode)

	r := gin.New()
	r.Use(middleware.Logger())
	r.Use(middleware.Recovery())
	r.Use(middleware.Prometheus())

	h := controller.NewHandler(cfg)

	r.GET("/", h.GetAppInfo)
	r.GET("/health", h.GetHealth)
	r.GET("/metrics", h.GetMetrics())
	r.NoRoute(h.NotFound)

	return r
}
