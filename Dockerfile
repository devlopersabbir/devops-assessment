# Stage 1: Build Stage
FROM golang:1.27.1-alpine AS builder

ARG APP_VERSION=1.0.0

WORKDIR /src

# Install CA certificates for HTTPS and git if needed for module downloads
RUN apk add --no-cache ca-certificates

# Copy dependency definitions first to leverage Docker layer caching
COPY app/go.mod app/go.sum ./
RUN go mod download && go mod verify

# Copy the Go application source code from app/ into /src
COPY app/ ./

# Build a statically linked, stripped binary for minimal size and security
RUN CGO_ENABLED=0 GOOS=linux GOARCH=amd64 \
    go build -trimpath \
    -ldflags="-w -s" \
    -o /src/server .

# Stage 2: Runtime Stage
FROM alpine:3.21.3 AS runtime

ARG APP_VERSION=1.0.0

# OCI standard image metadata labels
LABEL org.opencontainers.image.title="devops-assessment-api" \
      org.opencontainers.image.description="Lightweight Go Gin backend server with health check and Prometheus metrics" \
      org.opencontainers.image.version="${APP_VERSION}"

# Environment variables aligned with app/.env
ENV APP_ENV=production \
    LOG_LEVEL=info \
    APP_VERSION=${APP_VERSION} \
    PORT=8080 \
    GIN_MODE=release

# Install CA certificates and create a dedicated non-root user and group with no shell access
RUN apk add --no-cache ca-certificates && \
    addgroup -S -g 10001 appgroup && \
    adduser -S -u 10001 -G appgroup -h /app -s /sbin/nologin appuser && \
    mkdir -p /app && \
    chown -R appuser:appgroup /app && \
    chmod 750 /app

WORKDIR /app

# Copy compiled binary from builder with strict read+execute permissions owned by appuser:appgroup
COPY --from=builder --chown=appuser:appgroup --chmod=550 /src/server /app/server

# Switch to the unprivileged user
USER appuser:appgroup

EXPOSE 8080

# Liveness/Readiness healthcheck against GET /health
HEALTHCHECK --interval=30s --timeout=5s --start-period=10s --retries=3 \
    CMD wget --no-verbose --tries=1 --spider http://127.0.0.1:${PORT}/health || exit 1

ENTRYPOINT ["/app/server"]
