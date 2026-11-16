# DevOps Assessment - Production & Monitoring Stack

A production-ready Go HTTP API service equipped with a complete, fully-automated local observability and monitoring stack.

---

## 1. Quickstart

### Prerequisites
- Docker Engine 24+ & Docker Compose v2+
- Go 1.23+ (for local application development)

### Running the Entire Stack
Copy `.env.example` to `.env`:
```bash
cp .env.example .env
```

Start the application along with Prometheus, Grafana, Loki, Grafana Alloy, Node Exporter, and cAdvisor:
```bash
docker compose up -d --build
```

### Access Endpoints
| Component | Address | Credentials / Access |
|---|---|---|
| **Web API** | `http://localhost:8080/` | Public application traffic |
| **Liveness / Readiness** | `http://localhost:8080/health` | HTTP probe (`200 OK`) |
| **Prometheus Metrics** | `http://localhost:8080/metrics` | Prometheus scraper endpoint |
| **Grafana UI** | `http://localhost:3000` | User: `admin` \| Password: `AdminSecurePass123!` (configurable via `.env`) |
| **Prometheus, Loki, Alloy, Node Exporter, cAdvisor** | *Internal Only* | Isolated to `monitoring_network` |

---

## 2. Observability & Monitoring Architecture

The stack consists of all 6 mandatory components running on an isolated Docker network (`monitoring_network`):

```
                        ┌────────────────────────┐
                        │   Grafana (UI :3000)   │
                        └───────┬────────┬───────┘
                                │        │
                PromQL /metrics │        │ LogQL /loki
                                ▼        ▼
             ┌─────────────────────┐   ┌─────────────────────┐
             │ Prometheus (:9090)  │   │     Loki (:3100)    │
             └─▲─────────▲───────▲─┘   └──────────▲──────────┘
               │         │       │                │ Forwarded
        scrape │  scrape │scrape │                │ Docker logs
               │         │       │     ┌──────────┴──────────┐
               │         │       │     │ Grafana Alloy (:12345│
               │         │       │     └──────────▲──────────┘
               │         │       │                │ Docker Discovery
 ┌─────────────┴──┐ ┌────┴─────┐ ┌┴───────────┐ ┌─┴────────────────────────┐
 │ Node Exporter  │ │ cAdvisor │ │   Go API   │ │ Docker Engine Container  │
 │ (Host Metrics) │ │ (Docker) │ │  (:8080)   │ │ Logs (/var/run/docker.sock)
 └────────────────┘ └──────────┘ └────────────┘ └──────────────────────────┘
```

### Metrics Collection (Prometheus)
- **Targets Scraped**:
  - `devops-assessment-api`: Scrapes `/metrics` for request counts, error counts, and latency histograms.
  - `node-exporter`: Scrapes host hardware, CPU, memory, disk, and network stats.
  - `cadvisor`: Scrapes per-container metrics (CPU time, working set memory, limits).
- **Data Retention**: Explicitly configured to **15 days** (`--storage.tsdb.retention.time=15d`).

### Log Collection (Grafana Alloy & Loki)
- **Container Log Discovery**: Grafana Alloy connects directly to `/var/run/docker.sock` to dynamically discover running containers and tail stdout/stderr streams.
- **Log Parsing**: The API outputs structured JSON logs. Alloy's `stage.json` unpacks the JSON payload into fields: `level`, `method`, `path`, `status`, and `message`.
- **Low-Cardinality Label Strategy**:
  - `level` and `method` are extracted as indexed labels (cardinality is extremely low: ~4 log levels, ~5 HTTP methods).
  - High-cardinality fields like `path` and `status` are stored as **Loki Structured Metadata** (`stage.structured_metadata`). This enables ultra-fast filtering and querying without generating separate index streams that degrade Loki's index performance.
- **Data Retention**: Loki compactor is configured with explicit retention of **7 days** (`retention_period: 168h`).

---

## 3. Provisioned Dashboards as Code

All data sources and dashboards are provisioned automatically from repository YAML and JSON definitions under `monitoring/grafana/provisioning/`:

### 1. Application Dashboard (`uid: app-overview`)
- **Panels**:
  - **Request Rate (req/sec)**: Calculated via `sum(rate(http_requests_total[1m])) by (method, path)`.
  - **Error Rate (%)**: Monitored as ratio `sum(rate(http_requests_errors_total[1m])) / sum(rate(http_requests_total[1m]))`.
  - **Request Latency**: Visualizes p50, p95, and p99 percentiles from Prometheus bucket histograms (`http_request_duration_seconds_bucket`).
  - **Correlated Loki Logs**: Live LogQL panel (`{container="devops-assessment-api"} | json`) displaying real-time application logs right below the metric charts.

```
+------------------------------------------------------------------------------------------------------+
|                                     Application Dashboard                                            |
+------------------------------------+------------------------------------+----------------------------+
|  Request Rate (req/sec)           |  Error Rate (%)                    |  Latency (p50 / p95 / p99)  |
|  [~~~~~~~~~~ 45 req/s ~~~~~~~~~~~] |  [~~~~~~~~~~ 0.00% ~~~~~~~~~~~~~~] |  [ p50: 1.2ms | p99: 14ms ] |
+------------------------------------+------------------------------------+----------------------------+
|  Correlated Application Logs (Loki)                                                                  |
|  2026-11-16T13:21:26Z [INFO]  GET / - status=200 latency=0.8ms                                       |
|  2026-11-16T13:21:28Z [WARN]  GET /non-existent - status=404 latency=0.2ms                           |
|  2026-11-16T13:21:30Z [ERROR] GET /panic - status=500 Panic recovered: simulated panic              |
+------------------------------------------------------------------------------------------------------+
```

### 2. Host Dashboard (`uid: host-overview`)
- **Panels**:
  - **CPU Utilization (%)**: Total user, system, and I/O wait percentages from Node Exporter.
  - **Memory Usage**: Total, used, and cached/buffer allocations.
  - **Disk Usage (%)**: Filesystem capacity and percentage used per mountpoint.
  - **Network Traffic (Bytes/sec)**: Ingress/egress throughput across physical network interfaces.

```
+------------------------------------------------------------------------------------------------------+
|                                         Host Dashboard                                               |
+--------------------------------------------------+---------------------------------------------------+
|  Host CPU Utilization (%)                        |  Host Memory Usage                                |
|  [ User: 4.5% | System: 2.1% | Idle: 93.4% ]    |  [ Used: 3.8 GB / Total: 16.0 GB (Cached: 4.1GB) ]|
+--------------------------------------------------+---------------------------------------------------+
|  Host Disk Usage (%)                             |  Host Network Traffic (Bytes/sec)                 |
|  [ / : 42.1% used (58.9 GB free) ]               |  [ Rx: 120 KB/s | Tx: 85 KB/s ]                   |
+--------------------------------------------------+---------------------------------------------------+
```

---

## 4. Alerting Rules

Defined in `monitoring/prometheus/alerts/alert_rules.yml`:

| Alert Name | Condition | For Duration | Rationale & Severity |
|---|---|---|---|
| `AppInstanceDown` | `up{job="devops-api"} == 0` | `1m` | **Critical**: Triggers when Prometheus fails to scrape the API instance for 4 consecutive intervals (15s x 4 = 60s), indicating an application crash, dead container, or unroutable port. |
| `HighErrorRate` | `rate(errors[5m]) / rate(total[5m]) * 100 > 5` | `2m` | **Warning**: Detects when 4xx/5xx responses exceed 5% of all traffic over a rolling 5-minute window for 2 minutes. Avoids false alarms on single transient client errors while immediately flagging real degradation. |
| `HostDiskUsageHigh` | `disk_used / disk_total * 100 > 80` | `5m` | **Warning**: Fires when root filesystem storage exceeds 80% for 5 minutes. Gives operations engineers ample time to prune images or expand storage before out-of-disk crashes occur. |
| `ContainerMemoryNearLimit` | `memory_usage / memory_limit * 100 > 85` | `2m` | **Warning**: Fires when any container's memory consumption exceeds 85% of its hard limit for 2 minutes. Protects against imminent Out-Of-Memory (OOM) killer terminations. |

---

## 5. Security & Isolation Hygiene

1. **Host Exposure Minimization**:
   - Only **Grafana (`:3000`)** and **Web API (`:8080`)** publish ports to the host interface.
   - Prometheus (`:9090`), Loki (`:3100`), Grafana Alloy (`:12345`), Node Exporter (`:9100`), and cAdvisor (`:8080`) are restricted entirely to `monitoring_network`.
2. **Pinned Versioning**:
   - All Docker images specify exact semantic tags (e.g., `prom/prometheus:v3.2.1`, `grafana/loki:3.4.2`, `grafana/alloy:v1.7.5`, `grafana/grafana:11.5.2`, `prom/node-exporter:v1.9.0`, `gcr.io/cadvisor/cadvisor:v0.51.0`).
3. **Grafana Credentials as Environment Variables**:
   - `GF_SECURITY_ADMIN_USER` and `GF_SECURITY_ADMIN_PASSWORD` are injected dynamically from `.env`.
4. **Host Mounts & Privileges Documentation**:
   - **cAdvisor**:
     - Requires `/var/run/docker.sock` to communicate with the Docker daemon.
     - Requires `/sys` (cgroup hierarchies) to extract container kernel resource accounting.
     - Requires `/var/lib/docker/` to inspect container filesystem disk utilization.
     - Needs `privileged: true` and `/dev/kmsg` to monitor system kernel events and OOM killer notifications.
   - **Node Exporter**:
     - Requires `/proc` mapped to `/host/proc` and `/sys` mapped to `/host/sys` (`:ro`) to inspect host hardware without namespace virtualization.
     - Requires `/` mapped to `/rootfs:ro` to accurately calculate host disk partition metrics.
   - **Grafana Alloy**:
     - Mounts `/var/run/docker.sock:ro` strictly for Docker container discovery and log streaming.

---

## 6. Incident Walkthrough: Investigating an Error Spike

> **Scenario**: An error spike appears on the **Application Dashboard** under the **Error Rate (%)** panel. How do you find the root cause using these tools?

```
Step 1: Metric Detection
  Look at the "Error Rate (%)" panel on the Application Dashboard.
  Notice a sudden spike above 5% occurring at 13:21:30 UTC.
       │
       ▼
Step 2: Zoom and Correlate
  Click and drag across the time spike on the "Error Rate" graph to narrow the time range to [13:21:00 - 13:22:00].
  Observe which endpoint or method correlates with the spike in "Request Rate (req/sec)".
       │
       ▼
Step 3: In-Dashboard Log Inspection (Loki)
  Scroll down to the "Live Application Logs" panel positioned directly beneath the metrics on the same screen.
  Because the time range is synchronized, Loki instantly displays the log stream corresponding to the spike.
       │
       ▼
Step 4: Query and Filter Root Cause
  Apply a LogQL filter in the panel or jump to Grafana Explore:
      {container="devops-assessment-api", level="ERROR"} | json
  Inspect the log record:
      {
        "level": "ERROR",
        "method": "GET",
        "path": "/panic",
        "status": 500,
        "message": "Panic recovered on GET /panic: simulated unexpected panic"
      }
       │
       ▼
Step 5: Confirm System Impact
  Switch to the "Containers Dashboard" to verify whether the spike triggered a container restart or high CPU/memory usage.
  Confirm the API recovered gracefully via its Recovery middleware with zero container restarts.
```
