# Judge Helm Chart

![Version: 1.7.0](https://img.shields.io/badge/Version-1.7.0-informational?style=flat-square)
![Type: application](https://img.shields.io/badge/Type-application-informational?style=flat-square)
![AppVersion: v1.6.0](https://img.shields.io/badge/AppVersion-v1.6.0-informational?style=flat-square)

Production-ready Helm chart for deploying the complete Judge platform on Kubernetes with Istio service mesh, External Secrets Operator, and HashiCorp Vault integration.

## Table of Contents

- [Overview](#overview)
- [Prerequisites](#prerequisites)
- [Configuration](#configuration)
- [Installation](#installation)
- [External Secrets Operator](#external-secrets-operator)
- [OIDC Authentication](#oidc-authentication)
- [Istio Service Mesh](#istio-service-mesh)
- [Upgrading](#upgrading)
- [Uninstallation](#uninstallation)
- [Values Reference](#values-reference)
- [Troubleshooting](#troubleshooting)
- [Documentation](#documentation)

## Overview

This umbrella chart deploys the complete Judge platform, including:

- **Core Services**: judge-api, judge-web, archivista, judge-ai-proxy
- **Authentication**: Kratos (identity), Dex (OIDC provider)
- **PKI Services**: Fulcio (code signing CA), TSA (timestamping)
- **Infrastructure**: Dapr (workflows), optional MySQL, MinIO

The chart supports multi-cloud deployments (AWS, GCP, Azure) with provider-specific configurations for IAM, storage, and messaging.

## Prerequisites

- Kubernetes 1.24+
- Helm 3.8+
- Istio 1.18+ (optional but recommended)
- PostgreSQL database (AWS RDS, GCP CloudSQL, Azure Database, or self-hosted)
- S3-compatible object storage (AWS S3, GCP GCS, Azure Blob, or MinIO)
- HashiCorp Vault (optional, for External Secrets Operator integration)

## Configuration

### Quick Start: What You Must Configure

Before installation, you **must** configure these values in your `values.yaml`:

1. **Domain name** - `global.domain: your-domain.com`
2. **Cloud provider** - AWS account ID, region
3. **Container registry** - ECR repository URL
4. **Database connection** - RDS endpoint
5. **Object storage** - S3 bucket names
6. **IAM roles** - IRSA role ARNs for service accounts

See [demo-values.yaml](demo-values.yaml) for a complete working example.

### Provider Backend Pattern

Judge uses a Provider Backend Pattern for multi-cloud support. Configure your infrastructure provider in `values.yaml`:

```yaml
global:
  # Domain for all services (REQUIRED)
  domain: your-domain.com

  # Cloud infrastructure (REQUIRED)
  cloud:
    provider: aws  # aws, gcp, azure, local
    aws:
      accountId: "123456789012"
      region: us-east-1

  # Container registry (REQUIRED)
  registry:
    provider: aws-ecr  # aws-ecr, gcp-artifact, azure-acr, docker-hub
    url: YOUR_ACCOUNT_ID.dkr.ecr.REGION.amazonaws.com
    aws:
      region: us-east-1

  # Database (REQUIRED)
  database:
    provider: aws-rds  # aws-rds, gcp-cloudsql, azure-database, local-postgres
    type: postgresql
    port: 5432
    username: postgres
    aws:
      endpoint: your-rds-endpoint.region.rds.amazonaws.com
      region: us-east-1

  # Object storage (REQUIRED)
  storage:
    provider: aws-s3  # aws-s3, gcp-storage, azure-blob, minio
    buckets:
      archivista: your-archivista-bucket
      judgeApi: your-judge-api-bucket
    aws:
      region: us-east-1
      credentialType: IAM  # Use IRSA
      useTLS: true

  # Messaging (OPTIONAL - for event-driven features)
  messaging:
    provider: aws-sns-sqs  # aws-sns-sqs, gcp-pubsub, azure-servicebus
    aws:
      region: us-east-1
      snsTopicName: your-attestation-topic
      sqsQueueName: your-attestation-queue
```

### AWS Configuration with IAM Roles for Service Accounts (IRSA)

Complete AWS configuration example showing all required values:

```yaml
global:
  domain: your-domain.com
  cloud:
    provider: aws
    aws:
      accountId: "123456789012"
      region: us-east-1

  registry:
    provider: aws-ecr
    url: 123456789012.dkr.ecr.us-east-1.amazonaws.com
    aws:
      region: us-east-1

  database:
    provider: aws-rds
    type: postgresql
    port: 5432
    username: postgres
    aws:
      endpoint: judge-prod.us-east-1.rds.amazonaws.com

  storage:
    provider: aws-s3
    buckets:
      archivista: prod-judge-archivista
      judgeApi: prod-judge-api
    aws:
      region: us-east-1
      credentialType: IAM  # Use IRSA
      useTLS: true

# IAM Roles for Service Accounts (IRSA) - REQUIRED for AWS
archivista:
  serviceAccount:
    create: true
    annotations:
      eks.amazonaws.com/role-arn: arn:aws:iam::123456789012:role/prod-archivista

judge-api:
  serviceAccount:
    create: true
    annotations:
      eks.amazonaws.com/role-arn: arn:aws:iam::123456789012:role/prod-judge-api
```

**IMPORTANT**: You must create these IAM roles with appropriate S3, SNS, and SQS permissions. See [examples/terraform/aws/complete/](../../examples/terraform/aws/complete/) for complete infrastructure setup with Terraform.

### Database Architecture

**CRITICAL REQUIREMENT: Separate Databases Per Service**

Each Judge service MUST have its own PostgreSQL database on the same RDS/PostgreSQL instance:

- **judge_api**: Judge API artifact metadata, compliance frameworks, and policy data
- **archivista**: Archivista attestation metadata and search indices
- **kratos**: Kratos identity, sessions, and authentication data

**Why Separate Databases?**

Judge services use Atlas for database migrations, which tracks schema changes via hash-based versioning. Using a shared database causes migration conflicts:

```
Error: migration files were added out of order
```

**Setup Example:**

```sql
-- Connect to your PostgreSQL instance
psql "postgresql://postgres:password@your-rds-endpoint.amazonaws.com:5432/postgres"

-- Create separate databases
CREATE DATABASE judge_api;
CREATE DATABASE archivista;
CREATE DATABASE kratos;
```

Then configure each service's connection string to point to its dedicated database:

```yaml
global:
  database:
    provider: aws-rds
    aws:
      endpoint: your-rds-endpoint.amazonaws.com

# Each service connects to its own database via DSN
# archivista_dsn: postgresql://user:pass@endpoint:5432/archivista
# judge_api_dsn: postgresql://user:pass@endpoint:5432/judge_api
# kratos_dsn: postgresql://user:pass@endpoint:5432/kratos
```

### Database Credentials

Choose one of these methods to provide database credentials:

**Option 1: External Secrets Operator (Recommended for Production)**
```yaml
archivista:
  sqlStore:
    createSecret: false  # Delegate to ESO
    secretName: judge-judge-archivista-database

judge-api:
  sqlStore:
    createSecret: false
    secretName: judge-judge-api-database
```

See [External Secrets Operator](#external-secrets-operator) section below for complete setup.

**Option 2: Kubernetes Secrets (Quick Start)**
```yaml
global:
  secrets:
    provider: k8s-secrets
    database:
      passwordEncoded: "YOUR_URL_ENCODED_PASSWORD"
```

**IMPORTANT**: Never commit database passwords to version control. Use a separate `secrets.yaml` file (not committed) or ESO with Vault.

## Installation

### From Local Repository

```bash
# Clone the repository
git clone https://github.com/testifysec/judge-helm-charts.git
cd judge-helm-charts

# Build Helm dependencies
make deps

# Copy and configure values
cd charts/judge
cp demo-values.yaml values-production.yaml
vim values-production.yaml

# Install the chart
helm install judge . \
  --namespace judge \
  --create-namespace \
  --values values-production.yaml
```

### With ArgoCD (Recommended)

```yaml
apiVersion: argoproj.io/v1alpha1
kind: Application
metadata:
  name: judge-platform
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
    syncOptions:
      - CreateNamespace=true
```

## External Secrets Operator

Judge integrates with External Secrets Operator for dynamic secret management with HashiCorp Vault.

### Prerequisites

1. Install External Secrets Operator:
   ```bash
   helm repo add external-secrets https://charts.external-secrets.io
   helm install external-secrets external-secrets/external-secrets \
     --namespace external-secrets \
     --create-namespace
   ```

2. Configure Vault Kubernetes Auth (see [Terraform example](../../examples/terraform/aws/complete/main.tf#L414))

### Configuration

Enable ESO by setting `createSecret: false` for each service:

```yaml
archivista:
  sqlStore:
    createSecret: false  # Delegate secret creation to ESO
    secretName: judge-judge-archivista-database
  vault:
    enabled: false  # Using ESO instead of Vault Agent injection

judge-api:
  sqlStore:
    createSecret: false
    secretName: judge-judge-api-database
  vault:
    enabled: false

kratos:
  vault:
    enabled: false
```

The chart includes ExternalSecret templates that automatically sync secrets from Vault:

- `charts/archivista/templates/external-secret-database.yaml`
- `charts/judge-api/templates/external-secret-database.yaml`
- `charts/kratos/templates/external-secret-app.yaml`

### Secrets Synced from Vault

| Service | Vault Path | Keys | Refresh Interval |
|---------|-----------|------|------------------|
| archivista | `database/creds/archivista` | `connectionString` | 1 hour |
| judge-api | `database/creds/judge-api` | `connectionString` | 1 hour |
| kratos | `database/creds/kratos`<br/>`secret/data/{env}/kubernetes/app/testifysec-judge` | `connectionString`<br/>`oidc`, `smtp`, `secrets` | 1 hour |

## OIDC Authentication

Configure identity providers (GitHub, GitLab, Google, etc.):

```yaml
global:
  oidc:
    enabled: true
    providers:
      - id: github
        provider: github
        client_id: YOUR_GITHUB_OAUTH_CLIENT_ID
        # client_secret managed via ESO or secrets.yaml
        issuer_url: https://github.com
        mapper_url: file:///etc/config/kratos/github.jsonnet
        scope:
          - user
          - repo
          - read:org
```

**IMPORTANT**: Never commit `client_secret` to version control. Use:
- External Secrets Operator (recommended)
- Kubernetes Secrets (`secrets.yaml` not committed)
- Vault KV store

## Istio Service Mesh

The chart includes native Istio support with:

- **Service Port Naming**: Protocol-specific naming (`http-`, `grpc-`, etc.)
- **VirtualServices**: Intelligent routing for all exposed services
- **Gateway**: Centralized ingress with TLS termination
- **Dapr Compatibility**: Port exclusions prevent Dapr/Istio conflicts

### Exposed Services

After deployment with Istio Gateway:

| Service | URL | Purpose |
|---------|-----|---------|
| Judge Web UI | `https://judge.{domain}` | Primary web interface |
| Kratos Login | `https://login.{domain}` | Authentication UI |
| Archivista API | `https://archivista.{domain}` | Attestation API |
| Fulcio (future) | `https://fulcio.{domain}` | Code signing CA |
| TSA (future) | `https://tsa.{domain}` | Timestamping service |

### Accessing Services

```bash
# Get the ingress gateway external IP
kubectl get svc -n istio-system istio-ingressgateway

# Update DNS to point your domain to the LoadBalancer IP
# Example: judge.your-domain.com -> 52.1.2.3

# Access services
https://judge.your-domain.com
https://login.your-domain.com
```

## Upgrading

### Helm Upgrade

```bash
# Pull latest changes
git pull

# Rebuild dependencies if subcharts changed
make deps

# Upgrade release
helm upgrade judge charts/judge \
  --namespace judge \
  --values values-production.yaml
```

### ArgoCD Upgrade

ArgoCD automatically detects Git changes and syncs with `automated.selfHeal: true`.

## Uninstallation

```bash
# Delete Helm release
helm uninstall judge --namespace judge

# Delete namespace (WARNING: deletes all resources)
kubectl delete namespace judge

# Clean up Vault configuration (if using ESO)
# See Terraform for vault resource cleanup
```

## Values Reference

For complete configuration details:
- **All available options**: [values.yaml](values.yaml)
- **AWS deployment example**: [demo-values.yaml](demo-values.yaml)
- **Configuration guide**: [docs/configuring-judge-helm.md](docs/configuring-judge-helm.md)

Common customizations:
- **Replica counts**: `<service>.replicaCount`
- **Resource limits**: `<service>.resources`
- **Image tags**: `<service>.image.tag`
- **Service accounts**: `<service>.serviceAccount`
- **Environment variables**: `<service>.deployment.env`

## Troubleshooting

### Pods Not Starting

Check pod events and logs:
```bash
kubectl describe pod <pod-name> -n judge
kubectl logs <pod-name> -n judge
```

Common issues:
- **ImagePullBackOff**: Check registry credentials and ECR permissions
- **CrashLoopBackOff**: Check database connectivity and credentials
- **Pending**: Check resource requests and node capacity

### Database Connection Errors

Verify database credentials:
```bash
# For ESO deployments
kubectl get externalsecret -n judge
kubectl describe externalsecret judge-api-database -n judge

# Check Kubernetes Secret created by ESO
kubectl get secret judge-judge-api-database -n judge -o yaml
```

### Atlas Migration Errors

**Error: "migration files were added out of order"**

This error occurs when multiple services share the same PostgreSQL database:

```
Error: migration files 20241029143514_pgsql.sql, 20241101132730_seed_compliance_frameworks.sql,
2025012804232658_UpdateReleaseFramework.sql were added out of order.
```

**Root Cause:**

Atlas uses hash-based migration tracking in the `atlas_schema_revisions` table. When judge-api, archivista, and kratos share the same database, their migrations conflict because Atlas detects "out of order" changes from different services.

**Solution:**

Create separate databases for each service on the same RDS instance:

```bash
# 1. Create databases
kubectl apply -f - <<EOF
apiVersion: batch/v1
kind: Job
metadata:
  name: create-separate-databases
  namespace: judge
spec:
  template:
    spec:
      restartPolicy: Never
      containers:
      - name: create-dbs
        image: postgres:15
        command: ["/bin/bash", "-c"]
        args:
        - |
          psql "\$DATABASE_URL" <<'SQL'
          CREATE DATABASE judge_api;
          CREATE DATABASE archivista;
          CREATE DATABASE kratos;
          SQL
        env:
        - name: DATABASE_URL
          valueFrom:
            secretKeyRef:
              name: judge-platform-judge-api-database
              key: connectionString
EOF

# 2. Update Vault with separate DSNs
vault kv put secret/{env}/kubernetes/rds/testifysec-judge \
  judge_api_dsn="postgresql://user:pass@endpoint:5432/judge_api?sslmode=require" \
  archivista_dsn="postgresql://user:pass@endpoint:5432/archivista?sslmode=require" \
  kratos_dsn="postgresql://user:pass@endpoint:5432/kratos?sslmode=require"

# 3. Force External Secrets sync
kubectl annotate externalsecret -n judge judge-platform-judge-api-database \
  force-sync=$(date +%s) --overwrite
kubectl annotate externalsecret -n judge judge-platform-judge-archivista-database \
  force-sync=$(date +%s) --overwrite
kubectl annotate externalsecret -n judge judge-platform-judge-kratos \
  force-sync=$(date +%s) --overwrite

# 4. Restart all pods to pick up new database connections
kubectl rollout restart deployment -n judge
kubectl rollout restart statefulset -n judge
```

**Verification:**

```bash
# Check that each service connects to its own database
kubectl logs -n judge -l app=judge-api --tail=50 | grep "Running migrations"
kubectl logs -n judge -l app=archivista --tail=50 | grep "Running migrations"
kubectl logs -n judge -l app=kratos --tail=50 | grep "Running migrations"
```

Each service should show successful migrations without conflicts.

### Istio Issues

Check VirtualService and Gateway status:
```bash
kubectl get virtualservice -n judge
kubectl get gateway -n judge
istioctl analyze -n judge
```

## Documentation

### Getting Started

- [Getting Started Guide](docs/getting-started-with-judge-helm.md)
- [Configuration Reference](docs/configuring-judge-helm.md)

### Architecture

- [Component Architecture](../../docs/architecture/diagrams/component-architecture.md)
- [Secrets Management Flow](../../docs/architecture/diagrams/secrets-management.md)
- [Network Topology](../../docs/architecture/diagrams/network-topology.md)
- [Deployment Pipeline](../../docs/architecture/diagrams/deployment-pipeline.md)

### Deployment

- [Terraform AWS Examples](../../examples/terraform/aws/complete/)
- [Fulcio/TSA Trust Bootstrapping](../../docs/deployment/fulcio-tsa-trust-bootstrapping.md)

### Component-Specific Docs

- [Archivista](docs/archivista.md)
- [Judge API](docs/judge-api.md)
- [Judge Web](docs/judge-web.md)
- [Kratos](docs/kratos.md)

## Support

For issues, questions, or feature requests:
- GitHub Issues: https://github.com/testifysec/judge-helm-charts/issues
- Documentation: https://github.com/testifysec/judge-helm-charts
- TestifySec Support: Contact your account representative

## License

Copyright © TestifySec. All rights reserved. Proprietary and confidential.
