package main

import (
	"context"
	"net/http"
	"os"
	"os/signal"
	"syscall"
	"time"

	"github.com/devlopersabbir/devops-assessment/config"
	"github.com/devlopersabbir/devops-assessment/logger"
	"github.com/devlopersabbir/devops-assessment/router"
)

func main() {
	cfg := config.Load()
	addr := ":" + cfg.Port

	r := router.Setup(cfg)

	srv := &http.Server{
		Addr:         addr,
		Handler:      r,
		ReadTimeout:  10 * time.Second,
		WriteTimeout: 10 * time.Second,
		IdleTimeout:  60 * time.Second,
	}

	go func() {
		logger.Infof("Starting %s v%s on %s (env=%s)", cfg.AppName, cfg.AppVersion, addr, cfg.AppEnv)
		if err := srv.ListenAndServe(); err != nil && err != http.ErrServerClosed {
			logger.Fatalf("Server failed to start: %v", err)
		}
	}()

	quit := make(chan os.Signal, 1)
	signal.Notify(quit, syscall.SIGINT, syscall.SIGTERM)
	sig := <-quit
	logger.Infof("Received signal %v, shutting down server gracefully...", sig)

	ctx, cancel := context.WithTimeout(context.Background(), 5*time.Second)
	defer cancel()

	if err := srv.Shutdown(ctx); err != nil {
		logger.Fatalf("Server forced to shutdown: %v", err)
	}

	logger.Info("Server exited cleanly")
}
