APP_NAME ?= devops-assessment-api
VERSION  ?= $(if $(wildcard VERSION),$(strip $(file < VERSION)),1.0.0)
BUILD_DIR := bin
BINARY   := $(BUILD_DIR)/server

# Load environment variables from .env if it exists
ifneq (,$(wildcard .env))
    include .env
    export
endif

.PHONY: all help install deps build dev run test clean

all: install build

help: ## Display available Makefile targets
	@echo "Usage: make [target]"
	@echo ""
	@echo "Targets:"
	@echo "  install   Download and tidy Go module dependencies"
	@echo "  build     Compile the application binary into $(BINARY)"
	@echo "  dev       Run the application in development mode"
	@echo "  run       Alias for dev"
	@echo "  test      Run unit tests"
	@echo "  clean     Remove build artifacts"

install: ## Install and tidy Go packages
	go mod download
	go mod tidy
	go mod verify

deps: install ## Alias for install

build: ## Build the project binary
	@mkdir -p $(BUILD_DIR)
	go build -trimpath -ldflags="-w -s" -o $(BINARY) .

dev: ## Run the project in development mode
	go run .

run: dev ## Alias for dev

test: ## Run tests
	go test -v ./...

clean: ## Clean build artifacts
	rm -rf $(BUILD_DIR)
