#!/usr/bin/env bash
# Deploys and starts Prometheus Node Exporter container on port 3000
set -euxo pipefail

# Wait for Docker service to be fully up and running
for _ in $(seq 1 30); do
  if systemctl is-active --quiet docker; then
    break
  fi
  sleep 2
done

echo "=== Starting Node Exporter container on port 3000 ==="
docker pull prom/node-exporter:v1.9.0
docker rm -f node-exporter 2>/dev/null || true
docker run -d \
  --name node-exporter \
  --restart unless-stopped \
  -p 3000:9100 \
  prom/node-exporter:v1.9.0
