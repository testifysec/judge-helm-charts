# Judge Helm Charts

Production-ready Helm charts for deploying the Judge platform with Istio service mesh support, External Secrets Operator (ESO), and HashiCorp Vault integration.

## Table of Contents

- [Overview](#overview)
- [Features](#features)
- [Architecture](#architecture)
- [Quick Start](#quick-start)
- [Configuration](#configuration)
- [Production Deployment](#production-deployment)
- [External Secrets Operator Integration](#external-secrets-operator-integration)
- [Documentation](#documentation)
- [Development](#development)
- [Support](#support)

## Overview

This repository contains Helm charts for deploying the complete Judge platform to Kubernetes clusters. The charts support multi-cloud deployments (AWS, GCP, Azure) with built-in Istio service mesh integration, OIDC authentication, secrets management via Vault, and enterprise-grade security features.

## Features

- **Multi-Cloud Support**: Deploy to AWS (EKS), GCP (GKE), or Azure (AKS) with provider-specific configurations
- **Istio Service Mesh**: Native mTLS, traffic management, and observability integration
- **External Secrets Operator**: Seamless HashiCorp Vault integration for dynamic secret management
- **GitOps Ready**: Full ArgoCD support with sync waves for ordered deployments
- **IAM for Service Accounts**: AWS IRSA, GCP Workload Identity, Azure Workload Identity patterns
- **High Availability**: Multi-replica deployments with autoscaling and PodDisruptionBudgets
- **OIDC Authentication**: Flexible identity provider integration (GitHub, GitLab, Google, etc.)
- **Production-Ready Defaults**: Security-first configurations with least privilege principles

## Architecture

The Judge platform consists of the following components:

### Core Services
- **judge-api** - Core API service for artifact metadata and policy management
- **judge-web** - Web UI for platform management
- **archivista** - Attestation storage and retrieval service
- **judge-ai-proxy** - AI/LLM proxy service for intelligent policy suggestions

### Authentication & Identity
- **kratos** - Identity and user management (Ory Kratos)
- **kratos-selfservice-ui-node** - Self-service UI for login/registration
- **dex** - OpenID Connect (OIDC) provider for federated authentication

### PKI & Signing
- **fulcio** - Code signing certificate authority (TODO: CI/CD system integration)
- **tsa** - RFC 3161 timestamping authority (TODO: CI/CD system integration)

**Note**: Fulcio and TSA will be accessed by CI/CD systems in future releases for automated code signing and timestamping workflows. See [Fulcio/TSA Trust Bootstrapping](docs/deployment/fulcio-tsa-trust-bootstrapping.md) for implementation roadmap.

### Infrastructure
- **dapr** - Distributed application runtime for workflows and messaging

## Repository Structure

```
charts/
├── judge/                         # Umbrella chart - deploys all components
│   ├── Chart.yaml                # Dependencies and versions
│   ├── values.yaml               # Default configuration
│   ├── demo-values.yaml          # Example deployment configuration
│   ├── secrets.yaml.example      # Template for sensitive credentials
│   └── templates/
│       ├── _helpers.tpl          # Helm template helpers
│       ├── istio-gateway.yaml    # Istio Gateway configuration
│       ├── istio-virtualservices.yaml
│       └── ...
├── archivista/                   # Archivista subchart
├── judge-api/                    # Judge API subchart
├── judge-web/                    # Judge Web UI subchart
├── judge-ai-proxy/               # AI Proxy subchart
├── kratos/                       # Kratos subchart
├── kratos-selfservice-ui-node/   # Kratos UI subchart
├── dex/                          # Dex OIDC provider subchart
├── fulcio/                       # Fulcio subchart
├── tsa/                          # TSA subchart
└── dapr/                         # Dapr runtime subchart
```

## Quick Start

### Prerequisites

- Kubernetes 1.24+
- Helm 3.8+
- Istio 1.18+ (for service mesh features)
- PostgreSQL database (RDS, CloudSQL, or self-hosted)
- S3-compatible storage (S3, GCS, MinIO)

### Installation

1. **Clone the repository**
   ```bash
   git clone https://github.com/testifysec/judge-helm-charts.git
   cd judge-helm-charts
   ```

2. **Copy and configure values**
   ```bash
   cd charts/judge
   cp demo-values.yaml values.yaml
   cp secrets.yaml.example secrets.yaml

   # Edit values.yaml with your infrastructure configuration
   vim values.yaml

   # Edit secrets.yaml with sensitive credentials
   vim secrets.yaml
   ```

3. **Build Helm dependencies**
   ```bash
   cd ../..  # Back to repo root
   make deps
   ```

4. **Install the chart**
   ```bash
   helm install judge charts/judge \
     --namespace judge \
     --create-namespace \
     --values charts/judge/values.yaml \
     --values charts/judge/secrets.yaml
   ```

5. **Verify deployment**
   ```bash
   kubectl get pods -n judge
   kubectl get virtualservices -n judge
   ```

## Configuration

### Provider Backend Pattern

The charts use a Provider Backend Pattern for multi-cloud support. Configure each service provider in `values.yaml`:

```yaml
global:
  # Cloud infrastructure
  cloud:
    provider: aws  # aws, gcp, azure, local
    aws:
      accountId: "YOUR_AWS_ACCOUNT_ID"
      region: us-east-1

  # Container registry
  registry:
    provider: aws-ecr  # aws-ecr, gcp-artifact, azure-acr, docker-hub
    url: YOUR_ACCOUNT_ID.dkr.ecr.REGION.amazonaws.com
    aws:
      region: us-east-1
      accountId: "YOUR_AWS_ACCOUNT_ID"

  # Database
  database:
    provider: aws-rds  # aws-rds, gcp-cloudsql, azure-database, local-postgres
    type: postgresql
    aws:
      endpoint: your-rds-endpoint.region.rds.amazonaws.com
      region: us-east-1

  # Secrets management
  secrets:
    provider: k8s-secrets  # k8s-secrets, vault, aws-secrets, gcp-secrets
    database:
      passwordEncoded: "YOUR_URL_ENCODED_PASSWORD"

  # Object storage
  storage:
    provider: aws-s3  # aws-s3, gcp-storage, azure-blob, minio
    buckets:
      archivista: your-archivista-bucket
      judgeApi: your-judge-api-bucket
    aws:
      region: us-east-1

  # Messaging (pub/sub)
  messaging:
    provider: aws-sns-sqs  # aws-sns-sqs, gcp-pubsub, azure-servicebus
    aws:
      snsTopicName: your-attestation-topic
      sqsQueueName: your-attestation-queue
```

### Secrets Management

**IMPORTANT**: Never commit `secrets.yaml` to version control.

1. Copy the template: `cp secrets.yaml.example secrets.yaml`
2. Fill in your sensitive credentials
3. Deploy with both files: `helm install -f values.yaml -f secrets.yaml`

See `secrets.yaml.example` for the complete template.

### OIDC Authentication

Configure identity providers (GitHub, GitLab, Google, etc.) in `values.yaml`:

```yaml
global:
  oidc:
    enabled: true
    providers:
      - id: github
        provider: github
        client_id: YOUR_GITHUB_OAUTH_CLIENT_ID
        # client_secret in secrets.yaml
```

## Istio Integration

The charts include native Istio support:

- **Service Port Naming**: All services use protocol-specific port naming (`http-`, `grpc-`, etc.)
- **VirtualServices**: Intelligent routing for all exposed services
- **Gateway**: Centralized ingress with TLS termination
- **Dapr Compatibility**: Port exclusion annotations prevent Dapr/Istio conflicts

### Accessing Services

After deployment with Istio:

```bash
# Get the ingress gateway external IP
kubectl get svc -n istio-system istio-ingressgateway

# Access services (replace with your domain)
https://judge.your-domain.com       # Judge Web UI
https://login.your-domain.com       # Kratos login
https://archivista.your-domain.com  # Archivista API
```

## Development Workflow

### Helm Dependency Management

⚠️ **CRITICAL**: This repository uses file:// dependencies. Always run `make deps` after modifying subcharts.

```bash
# Modify a subchart
vim charts/judge-api/templates/deployment.yaml

# Rebuild dependencies (REQUIRED!)
make deps

# Commit both source and packaged files
git add charts/judge-api/templates/deployment.yaml
git add charts/judge/charts/*.tgz
git commit -m "feat: update judge-api deployment"
```

### Automatic Dependency Management with Pre-Commit Hooks

A pre-commit hook is installed that **automatically rebuilds Helm dependencies** whenever `Chart.yaml` changes:

```bash
# Hook automatically triggers when:
$ git add charts/judge/Chart.yaml
$ git commit -m "deps: update tsa subchart version"
# → Hook runs: helm dependency build charts/judge
# → Hook adds: charts/judge/Chart.lock to commit
# ✅ Commit succeeds with locked dependencies
```

**Why this matters for ArgoCD:**

ArgoCD cannot resolve local `file://` repository paths - it needs concrete chart versions locked in `Chart.lock`. Without this:
- ArgoCD uses cached/stale chart versions
- Template changes aren't reflected in rendered manifests
- Resources show as `OutOfSync` despite fixes being committed

**If you modify `Chart.yaml` manually** and the hook doesn't run:
```bash
# Force dependency rebuild
make deps
git add charts/*/Chart.lock
git commit -m "deps: rebuild after Chart.yaml update"
```

### Makefile Targets

| Command | Purpose |
|---------|---------|
| `make deps` | Rebuild all Helm dependencies and Chart.lock |
| `make check-deps` | Verify Chart.lock files are current with Chart.yaml |
| `make validate` | Validate Helm templates |
| `make test` | Run all checks |
| `make clean` | Remove .tgz files |
| `make help` | Show all targets |

See [CONTRIBUTING.md](CONTRIBUTING.md) for detailed workflow.

## Production Deployment

### Recommended Configuration

For production deployments:

1. **External Database**: Use managed PostgreSQL (RDS, CloudSQL, Azure Database)
   ```yaml
   mysql:
     enabled: false  # Disable embedded MySQL

   global:
     database:
       provider: aws-rds
       aws:
         endpoint: prod-db.region.rds.amazonaws.com
   ```

2. **External Object Storage**: Use cloud storage (S3, GCS, Azure Blob)
   ```yaml
   minio:
     enabled: false  # Disable embedded MinIO

   global:
     storage:
       provider: aws-s3
       buckets:
         archivista: prod-archivista-bucket
   ```

3. **High Availability**: Scale replicas for critical services
   ```yaml
   judge-api:
     replicaCount: 3

   archivista:
     replicaCount: 3
   ```

4. **Resource Limits**: Configure appropriate CPU/memory limits
   ```yaml
   judge-api:
     resources:
       requests:
         memory: "1Gi"
         cpu: "500m"
       limits:
         memory: "2Gi"
         cpu: "1000m"
   ```

### GitOps with ArgoCD

Example ArgoCD Application:

```yaml
apiVersion: argoproj.io/v1alpha1
kind: Application
metadata:
  name: judge-production
  namespace: argocd
spec:
  project: default
  source:
    repoURL: https://github.com/testifysec/judge-helm-charts
    targetRevision: main
    path: charts/judge
    helm:
      valueFiles:
        - values-production.yaml
  destination:
    server: https://kubernetes.default.svc
    namespace: judge
  syncPolicy:
    automated:
      prune: true
      selfHeal: true
```

## External Secrets Operator Integration

Judge platform integrates with External Secrets Operator for secure, dynamic secret management:

### Features

- **Dynamic Database Credentials**: Vault Database Secrets Engine generates short-lived PostgreSQL credentials (24h TTL)
- **Automatic Rotation**: Secrets refresh every 1 hour with automatic pod restart
- **Vault Kubernetes Auth**: ServiceAccount JWT-based authentication to Vault
- **Static Secrets**: OIDC client secrets, SMTP credentials managed via Vault KV
- **No Hardcoded Secrets**: All sensitive data sourced from Vault at runtime

### Configuration

```yaml
global:
  secrets:
    provider: vault  # Use vault instead of k8s-secrets

archivista:
  sqlStore:
    createSecret: false  # Delegate to ESO
    secretName: judge-judge-archivista-database
  vault:
    enabled: false  # Using ESO instead of Vault Agent
```

See [examples/terraform/aws/complete/](examples/terraform/aws/complete/) for complete Vault configuration with Terraform.

## Documentation

### Architecture & Design

- [Component Architecture](docs/architecture/diagrams/component-architecture.md) - High-level system architecture
- [Secrets Management](docs/architecture/diagrams/secrets-management.md) - ESO + Vault integration flow
- [Network Topology](docs/architecture/diagrams/network-topology.md) - Istio service mesh and AWS VPC
- [Deployment Pipeline](docs/architecture/diagrams/deployment-pipeline.md) - GitOps workflow with ArgoCD

### Deployment Guides

- [Terraform AWS Examples](examples/terraform/aws/complete/) - Complete infrastructure as code examples
- [Fulcio and TSA Trust Bootstrapping](docs/deployment/fulcio-tsa-trust-bootstrapping.md) - PKI implementation roadmap
- [Getting Started](charts/judge/docs/getting-started-with-judge-helm.md) - Initial setup guide
- [Configuring Judge Helm](charts/judge/docs/configuring-judge-helm.md) - Complete configuration reference

### External References

- [DEVELOPMENT.md](DEVELOPMENT.md) - Technical architecture and configuration details
- [CONTRIBUTING.md](CONTRIBUTING.md) - Development workflow and contribution guidelines
- [Istio Integration](https://istio.io/latest/docs/ops/deployment/application-requirements/)
- [Helm Best Practices](https://helm.sh/docs/chart_best_practices/)
- [External Secrets Operator](https://external-secrets.io/)
- [Vault Kubernetes Auth](https://www.vaultproject.io/docs/auth/kubernetes)

## Support

For issues, questions, or feature requests, please contact TestifySec support or open an issue in this repository.

## License

Copyright © TestifySec. All rights reserved. Proprietary and confidential.
