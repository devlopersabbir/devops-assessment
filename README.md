# DevOps Assessment - Production Web Service & Platform

End-to-end, production-ready DevOps implementation for building, shipping, orchestrating, and observing a resilient web service across local Docker Compose, Kubernetes, and AWS infrastructure provisioned via Terraform.

---

## Table of Contents

- [Initialization - Git Branching & Deployment Strategy](#initialization--git-branching--deployment-strategy)
- [Step 1: Application & Containerization](#step-1-application--containerization)
- [Step 2: CI/CD Pipeline (GitHub Actions)](#step-2-cicd-pipeline-github-actions)
- [Step 3: Infrastructure as Code (Terraform)](#step-3-infrastructure-as-code-terraform)
- [Step 4: Kubernetes Deployment](#step-4-kubernetes-deployment)
- [Step 5: Observability Stack](#step-5-observability-stack)
- [Step 6: Linux Automation Scripting](#step-6-linux-automation-scripting)
- [Design Decisions & Trade-Offs](#design-decisions--trade-offs)
- [Deployment & Rollback Strategy](#deployment--rollback-strategy)
- [Security Considerations](#security-considerations)
- [AWS Production Cost Estimation](#aws-production-cost-estimation)
- [What I Would Improve With More Time](#what-i-would-improve-with-more-time)
- [AI Tool Usage Disclosure](#ai-tool-usage-disclosure)

---

## Initialization - Git Branching & Deployment Strategy

- **`master` (Staging Environment):** Merges into `master` automatically trigger a zero-downtime deployment to the AWS Staging environment (`http://3.111.180.6:8080`).
- **`main` (Production Environment):** Merges into `main` trigger a zero-downtime rolling deployment to the AWS Production environment (`http://devops-assessment-prod-alb-2108406691.ap-south-1.elb.amazonaws.com`).

Both deployment pipelines enforce strict pre-flight quality and security gates—including code linting (`golangci-lint`), shell scripting linting (`shellcheck`), Dockerfile validation (`hadolint`), automated unit testing with coverage, and container vulnerability scanning (`Trivy` failing on `CRITICAL`)—prior to releasing zero-downtime updates via AWS Systems Manager (SSM).

## Step 1: Application & Containerization

A lightweight Go backend server built with the **Gin** framework serving three core endpoints:

- `GET /`: Returns service metadata `{"message": "Hello from DevOps Task!", "status": "running", "version": "1.0.0"}`.
- `GET /health`: Liveness and readiness health probe returning `{"status": "ok"}`.
- `GET /metrics`: Exposes Prometheus-formatted metrics including request count (`http_requests_total`), error count (`http_requests_errors_total`), and latency histogram (`http_request_duration_seconds`).

### Multi-Stage Docker Build & Security Hardening

- Built using a multi-stage `Dockerfile` (`golang:1.27-alpine` builder $\rightarrow$ `alpine:3.21` runtime) to produce a minimal, production-grade image:
  - **Final Image Size:** **34.8 MB** disk usage (compressed download size: **9.86 MB**).
- Runs strictly as an unprivileged non-root user (`appuser:10001`) with a read-only root filesystem, dropped capabilities (`cap-drop: ALL`), and `no-new-privileges:true` to ensure container escape protection and isolate the host machine.

### Local Development

Run the containerized application locally with defined CPU (0.50) and memory (128 MB) limits using `docker-compose.yaml`:

```bash
docker compose up -d --build
```

## Step 2: CI/CD Pipeline (GitHub Actions)

```mermaid
flowchart TD
    A["Code Push / PR"] --> B["Quality & Code Gates"]
    subgraph B ["CI: Quality Gates"]
        B1["Linting (golangci-lint, hadolint, shellcheck)"]
        B2["Unit Tests & Coverage"]
    end
    B --> C["CD: Build Multi-Arch Docker Image"]
    C --> D["Security: Container Vulnerability Scan (Trivy - Fails on CRITICAL)"]
    D --> E["Publish Image to GHCR (Tagged with SHA & SemVer)"]
    E --> F{"Target Environment (Branch)"}
    F -->|"master branch"| G["Deploy to Staging EC2 via AWS SSM"]
    F -->|"main branch"| H["Rolling Deploy to Prod ASG via AWS SSM"]
    G --> I["Health Check Smoke Test & Auto-Rollback on Failure"]
    H --> I
    I --> J["Discord Notification (Success / Failure Status Alert)"]
```

### Environment-Based Deployment & Security

- **Branch-Based Target Resolution:** The workflow dynamically routes deployments based on the branch reference:
  - `master` $\rightarrow$ deploys to the standalone **Staging** instance.
  - `main` $\rightarrow$ initiates a zero-downtime rolling update across the **Production** Auto Scaling Group behind the ALB.
- **Docker Image Vulnerability Scanning:** Every container image is scanned by **Trivy** before being pushed to GHCR. Any detected `CRITICAL` vulnerability halts the pipeline immediately.
- **Agent-Based Deployment via AWS SSM:** Zero SSH exposure. Port 22 is entirely closed on all EC2 security groups. Commands and rolling container swaps are executed securely over the AWS Systems Manager (SSM) agent session.
- **Zero Hardcoded Secrets:** All credentials (`AWS_ACCESS_KEY_ID`, `AWS_SECRET_ACCESS_KEY`, `GHCR_TOKEN`, `DISCORD_WEBHOOK_URL`) are injected at runtime via GitHub Actions encrypted secrets.
- **Automated Rollback & Real-Time Alerts:** Pre-swap `/health` checks verify new containers before traffic switchover; failed deployments revert to the previous image tag automatically and dispatch instant failure alerts to **Discord**. Successful production and staging rollouts trigger success summaries with image metadata.

## Step 3: Infrastructure as Code (Terraform)

### 1. Terraform Remote State Bootstrap Architecture

```mermaid
flowchart TD
    DevOpsEng["DevOps Engineer / CI Runner"] -->|"terraform apply (terraform/bootstrap)"| BootstrapModule["Terraform Bootstrap Engine"]

    subgraph BootstrapInfra ["AWS S3 & DynamoDB Remote State Backend (ap-south-1)"]
        subgraph StagingBackend ["Staging State Store"]
            S3_Staging["S3 Bucket: devops-assessment-staging-tfstate-1<br>• Versioning: Enabled<br>• Encryption: AES256 (SSE-S3)<br>• Public Access: Blocked"]
            DDB_Staging["DynamoDB Table: devops-assessment-staging-tflocks<br>• Partition Key: LockID (String)<br>• Prevents Concurrent Applies"]
        end

        subgraph ProdBackend ["Production State Store"]
            S3_Prod["S3 Bucket: devops-assessment-prod-tfstate-1<br>• Versioning: Enabled<br>• Encryption: AES256 (SSE-S3)<br>• Public Access: Blocked"]
            DDB_Prod["DynamoDB Table: devops-assessment-prod-tflocks<br>• Partition Key: LockID (String)<br>• Prevents Concurrent Applies"]
        end
    end

    BootstrapModule --> StagingBackend
    BootstrapModule --> ProdBackend

    StagingBackend -.->|"State Locking & Storage"| StagingTerraform["terraform/environments/staging"]
    ProdBackend -.->|"State Locking & Storage"| ProdTerraform["terraform/environments/prod"]
```

---

### 2. Staging Infrastructure Architecture (Cost-Effective & Isolated)

```mermaid
flowchart TD
    User["Developer / Tester"] -->|"HTTP: 3.111.180.6:8080"| EIP["Elastic IP (3.111.180.6)"]

    subgraph StagingVPC ["Staging VPC (10.1.0.0/16) - ap-south-1"]
        IGW_S["Internet Gateway"] --> EIP
        subgraph PublicSubnet_S ["Public Subnet (10.1.1.0/24)"]
            EIP --> EC2_S["EC2 Instance (t3.small)<br>devops-assessment-staging-ec2"]
            EC2_S --> AppContainer_S["Docker Container<br>devops-assessment-api (Port 8080)"]
            EC2_S --- SG_S["Security Group<br>Allow: 80, 8080, 3000<br>Port 22 (SSH): CLOSED"]
            EC2_S --- IAM_S["IAM Role<br>AmazonSSMManagedInstanceCore<br>(SSM Session Access Only)"]
        end
    end

    AWS_SSM["AWS Systems Manager (SSM)"] -.->|"Zero-SSH Deploy & Session Access"| EC2_S
```

---

### 3. Production Infrastructure Architecture (Multi-AZ High Availability)

```mermaid
flowchart TD
    PublicUsers["Internet Traffic"] -->|"HTTP / HTTPS"| Route53["DNS / External Clients"]
    Route53 --> ALB["Application Load Balancer (ALB)"]

    subgraph ProdVPC ["Production VPC (10.0.0.0/16) - ap-south-1"]
        IGW_P["Internet Gateway"] --- ALB

        subgraph PublicSubnets ["Public Subnets (Multi-AZ)"]
            direction LR
            PubSubA["Public Subnet A<br>ap-south-1a (10.0.1.0/24)"]
            PubSubB["Public Subnet B<br>ap-south-1b (10.0.2.0/24)"]
            NAT_GW["NAT Gateway (ap-south-1a)"]
        end

        ALB --> TargetGroup["ALB Target Group (Health Probes: /health)"]

        subgraph PrivateSubnets ["Private Workload Subnets (Zero Public IPs)"]
            direction LR
            PrivSubA["Private Subnet A<br>ap-south-1a (10.0.10.0/24)"]
            PrivSubB["Private Subnet B<br>ap-south-1b (10.0.20.0/24)"]

            TargetGroup --> ASG["Auto Scaling Group (ASG)<br>Launch Template | Min: 2, Desired: 2, Max: 4"]
            ASG --> EC2_P1["EC2 Instance (t3.micro)<br>devops-assessment-prod-server"]
            ASG --> EC2_P2["EC2 Instance (t3.micro)<br>devops-assessment-prod-server"]

            EC2_P1 --- SG_P["Security Group<br>Inbound from ALB only<br>Port 22: CLOSED"]
            EC2_P2 --- SG_P

            EC2_P1 --- IAM_P["IAM Role (SSM + CloudWatch)"]
            EC2_P2 --- IAM_P
        end

        PrivateSubnets -.->|"Outbound Internet via NAT"| NAT_GW
        NAT_GW --> IGW_P
    end

    subgraph ObservabilityAlerting ["Alerting & Notifications"]
        CW_Alarms["CloudWatch Alarms<br>(High CPU, Unhealthy Hosts, 5XX)"] --> SNS_Topic["SNS Alert Topic"]
        SNS_Topic --> Lambda_Discord["Lambda Notifier"] --> Discord_Channel["Discord Alert Channel"]
    end

    ProdSSM["AWS Systems Manager (SSM)"] -.->|"Zero-SSH Rolling Deployment"| ASG
```

### Architecture & Network Isolation

- **Dedicated Dual VPCs:** Staging (`10.1.0.0/16`) and Production (`10.0.0.0/16`) are fully segregated with zero network peering, ensuring complete environment isolation.
- **Production High Availability:** Spans 2 Availability Zones (`ap-south-1a`, `ap-south-1b`) with public/private subnet topology. Workloads run inside private subnets behind an Application Load Balancer with outbound internet provided via NAT Gateway.
- **Lightweight Staging:** Cost-effective single-instance setup (`t3.small`) bound to a static Elastic IP for straightforward validation without ALB/NAT overhead.
- **IAM Least Privilege & Zero SSH:** No static IAM credentials exist on instances. All access is governed via AWS Systems Manager (`AmazonSSMManagedInstanceCore`). CloudWatch logging and alarms are strictly provisioned on Production (`prod`), keeping Staging lean without extra agent overhead. Port 22 is disabled across all security groups.
- **State Management:** S3 remote backends with AES-256 encryption, bucket versioning, and DynamoDB-backed state locking to prevent concurrent modifications.

### Evidence of Plan & Apply

Execution logs and verification outputs are archived in `screenshots/terraform/`:

- [`screenshots/terraform/staging-plan.png`](screenshots/terraform/staging-plan.png) — Staging resource execution plan
- [`screenshots/terraform/staging-apply.png`](screenshots/terraform/staging-apply.png) — Staging resources successfully provisioned
- [`screenshots/terraform/prod-plan.png`](screenshots/terraform/prod-plan.png) — Production resource execution plan
- [`screenshots/terraform/prod-apply.png`](screenshots/terraform/prod-apply.png) — Production multi-AZ resources successfully provisioned

---

## Step 4: Kubernetes Deployment

Local Kubernetes architecture deployed on **Minikube** under the isolated `devops-assessment` namespace.

```mermaid
flowchart TD
    Client["Client / curl"] -->|"kubectl port-forward 8080:80"| SVC["Service: ClusterIP (Port 80 -> 8080)"]
    SVC --> Pods["Pods (Replicas: 2 - 5)"]

    subgraph K8sCluster ["Namespace: devops-assessment"]
        SVC
        subgraph Deployment ["Deployment: devops-assessment-server"]
            Pods
            HPA["HorizontalPodAutoscaler (Target: 70% CPU)"] -.->|"Scales"| Pods
            ConfigMap["ConfigMap: app-config (Port, Env, LogLevel)"] --> Pods
            Secret["Secret: ghcr-secret (Pull Token)"] --> Pods
        end
    end
```

### Manifest Specifications (`k8s/`)

- **`deployment.yaml`:**
  - High availability: Min 2 replicas with `RollingUpdate` strategy (`maxSurge: 1`, `maxUnavailable: 0`).
  - Container hardening: `runAsNonRoot: true` (`UID/GID 10001`), `readOnlyRootFilesystem: true`, capabilities dropped (`ALL`), `allowPrivilegeEscalation: false`.
  - Resource governance: Requests (`50m` CPU, `64Mi` RAM) and Limits (`250m` CPU, `128Mi` RAM).
  - Health probes: Liveness (`/health`, 10s period) and Readiness (`/health`, 5s period).
- **`service.yaml`:** Exposes backend pods internally via `ClusterIP` on port 80.
- **`hpa.yaml`:** `HorizontalPodAutoscaler` scaling from 2 to 5 pods when average CPU utilization exceeds 70%.
- **`configmap.yaml` & `dotenv-secret.yaml`:** Decoupled runtime configuration (`app-config`) and Git-ignored image pull credentials (`ghcr-secret` from `dotenv-secret.yaml.example`).

---

### Local Deployment & Access via Port-Forwarding

```bash
# 0. Start Minikube & enable metrics-server for HPA
minikube start
minikube addons enable metrics-server

# 1. Create namespace, config, and secret
kubectl apply -f k8s/namespace.yaml
kubectl apply -f k8s/configmap.yaml

# Generate image pull secret from template (copy dotenv-secret.yaml.example -> dotenv-secret.yaml)
kubectl apply -f k8s/dotenv-secret.yaml

# 2. Deploy application and HPA
kubectl apply -f k8s/deployment.yaml
kubectl apply -f k8s/service.yaml
kubectl apply -f k8s/hpa.yaml

# 3. Access locally via Port-Forwarding
kubectl port-forward -n devops-assessment svc/devops-assessment-service 8080:80
```

Verify service in another terminal:

```bash
curl -s http://localhost:8080/
# {"message":"Hello from DevOps Task!","status":"running","version":"1.0.0"}

curl -s http://localhost:8080/health
# {"status":"ok"}
```

#### Evidence of Running Workload

- [`screenshots/k8s/get-all.png`](screenshots/k8s/get-all.png) — Verified cluster state showing active Pods, Service, Deployment, and HPA in Minikube (`kubectl get all -n devops-assessment`).

---

### Zero-Downtime Rolling Update & Rollback Verification

```bash
# Trigger rolling update to new image version
kubectl set image deployment/devops-assessment-server server=ghcr.io/devlopersabbir/devops-assessment:1.1.0 -n devops-assessment

# Monitor zero-downtime rollout in real time
kubectl rollout status deployment/devops-assessment-server -n devops-assessment
# Output: deployment "devops-assessment-server" successfully rolled out

# Verify rollout history
kubectl rollout history deployment/devops-assessment-server -n devops-assessment

# Instant rollback to the previous working revision if an issue occurs
kubectl rollout undo deployment/devops-assessment-server -n devops-assessment
# Output: deployment.apps/devops-assessment-server rolled back
```

---

### Production EKS Transition (What Would Change)

To migrate this local setup to a production-grade Amazon EKS cluster:

1. **Ingress & TLS:** Replace port-forwarding with **AWS Load Balancer Controller** managing an Internet-facing Application Load Balancer via standard `Ingress`, with TLS certificates automated via **AWS Certificate Manager (ACM)**.
2. **Dynamic Secrets Management:** Replace static Kubernetes Secrets with **External Secrets Operator (ESO)** integrating directly with **AWS Secrets Manager** or **AWS Systems Manager Parameter Store** (enabling automatic secret rotation with zero hardcoded values).
3. **IAM Roles for Service Accounts (IRSA / EKS Pod Identity):** Replace static tokens with AWS Pod Identity or IRSA, granting pods fine-grained, temporary IAM permissions (e.g., S3 or DynamoDB access) without static keys.
4. **Intelligent Node Autoscaling:** Deploy **Karpenter** alongside the `HorizontalPodAutoscaler` to dynamically provision right-sized, cost-optimized EC2 Graviton/AMD instances in seconds directly in response to pod resource requests.
5. **Observability & Network Policies:** Leverage **Amazon VPC CNI** for native VPC IP allocation and install **Cilium / Calico** to enforce strict zero-trust egress and ingress NetworkPolicies between namespaces.
