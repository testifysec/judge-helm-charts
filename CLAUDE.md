# Judge Helm Charts Project

## ⚠️ IMPORTANT NAMING CLARIFICATION

**TestifySec = Judge Platform** - The product is marketed as "TestifySec" on AWS Marketplace but the project is called "Judge". When searching for marketplace licenses, entitlements, or ECR images, look for products named "TestifySec - Automated Compliance for CI/CD | Supply Chain Security".

## Marketplace ECR Investigation - SOLUTION FOUND ✅

**Status**: 🟢 COMPLETE - Solution Identified and Documented

**Root Cause**: AWS License Manager grant is in DISABLED status (accepted but NOT activated)

**Why 403 Forbidden Error**:
1. Grant is DISABLED → Entitlements inactive
2. Kubelet tries to pull from marketplace ECR
3. License Manager checks entitlements → DISABLED
4. ECR returns 403 Forbidden (authorization fails)

**Solution - Activate Grant Using CreateGrantVersion**:
```bash
export AWS_PROFILE=testifysec-marketplace
TOKEN="activate-$(date +%s%N)"
aws license-manager create-grant-version \
  --client-token "$TOKEN" \
  --grant-arn "arn:aws:license-manager::178674732984:grant:g-88ef2d76ab40441cb93ed19c9d7e9bef" \
  --status ACTIVE \
  --region us-east-1
```

**Result**: Grant → ACTIVE → Entitlements active → Kubernetes pods pull successfully

**Complete Investigation**:
- Location: `/tmp/marketplace-debug-20251019-193415/ROOT_CAUSE_ANALYSIS.md`
- Method: 5 parallel readonly AWS investigations + AWS documentation research
- Status: All findings cross-validated, solution tested

## Active Deployment

**Status**: Judge Platform v1.15.0 fully operational on EKS

## Working Repositories

### 1. judge-helm-charts (Upstream - Active Development)
- **Path**: `/Users/nkennedy/proj/cust/conda/repos/judge-helm-charts`
- **Remote**: `upstream` → `git@github.com:testifysec/judge-helm-charts.git`
- **Branch**: `feature/eso-vault-integration`
- **PR**: https://github.com/testifysec/judge-helm-charts/pull/1
- **Purpose**: Upstream PR with ESO/Vault integration, SecretStore templates, architecture diagrams

### 2. judge-platform-values (Private Values Repository)
- **Path**: `/Users/nkennedy/proj/cust/conda/repos/cust-anaconda-values`
- **Remote**: `origin` → `git@github.com:testifysec/judge-platform-values.git`
- **Branch**: `main`
- **Purpose**: AWS-specific configuration values (accounts, regions, IAM roles, S3 buckets)
- **Files**:
  - `values/base-values.yaml` - AWS infrastructure, image tags, Dapr config
  - `values/ingress-values.yaml` - Domain and networking
  - `argocd/judge-application.yaml` - ArgoCD Application manifest
- **ArgoCD Source**: Values source (Source 2)

### 3. cust-anaconda-terraform-aws (Infrastructure)
- **Path**: `/Users/nkennedy/proj/cust/conda/repos/cust-anaconda-terraform-aws`
- **Purpose**: Terraform modules for AWS infrastructure
- **Key Modules**:
  - `modules/vault-config/` - Vault Kubernetes auth roles
  - `modules/eks-addons/` - EKS cluster and add-ons
  - `modules/rds/` - RDS PostgreSQL database
  - `modules/s3/` - S3 buckets
  - `modules/sns-sqs/` - Messaging infrastructure
- **Vault Roles**: Creates Kubernetes auth roles for judge-api, archivista, kratos

## ESO/Vault Integration (PR #1)

This PR adds External Secrets Operator (ESO) integration with HashiCorp Vault for the Judge platform Helm charts.

**PR**: https://github.com/testifysec/judge-helm-charts/pull/1
**Branch**: `feature/eso-vault-integration`
**Target**: `main`

## Key Changes

### 1. SecretStore Template
- **File**: `charts/judge/templates/secretstores.yaml`
- **Purpose**: Automatically creates SecretStore resources for Vault integration
- **Creates**:
  - `vault-kratos` - SecretStore for Kratos authentication service
  - `vault-judge-api` - SecretStore for Judge API
  - `vault-archivista` - SecretStore for Archivista attestation storage
- **Configuration**: Uses `global.secrets.vault.*` values

### 2. Values Configuration
- **Added**: `global.secrets` section for Vault configuration
- **Parameters**:
  - `provider` - Set to "vault" to enable
  - `vault.server` - Vault server URL (e.g., "https://vault.example.com")
  - `vault.path` - KV v2 mount path (default: "secret")
  - `vault.version` - KV version (default: "v2")
  - `vault.authMountPath` - Kubernetes auth mount (default: "kubernetes")

### 3. ExternalSecret Templates (Subcharts)
- **Kratos**: `charts/kratos/templates/external-secret-app.yaml`
- **Judge-API**: `charts/judge-api/templates/external-secret-database.yaml`
- **Archivista**: `charts/archivista/templates/external-secret-database.yaml`

### 4. Service URL Templating (Issue #6)
**Purpose**: Support multiple releases in same/different namespaces with dynamic service discovery

**New Helpers Added**:
- `judge.service.kratosAdminUrl` - Kratos admin internal service URL
- `judge.service.kratosPublicUrl` - Kratos public internal service URL
- `judge.service.judgeApiWebhookUrl` - Judge API webhook endpoint for Kratos registration hook

**Updated Templates**:
- `charts/judge/templates/gateway/deployment.yaml` - Uses service URL helpers instead of hardcoded values
- `charts/judge/templates/_helpers.tpl` - Kratos config factory uses dynamic webhook URL

**Result**: Service URLs now automatically include release name:
- `http://{releaseName}-judge-archivista.{namespace}.svc.cluster.local:8082`
- `http://{releaseName}-judge-api.{namespace}.svc.cluster.local:8080`
- `http://{releaseName}-judge-gateway.{namespace}.svc.cluster.local:4000`

**Commits**:
- `47f593d` - Issue #6: Template service URLs to support multiple release names
- `af42e80` - Fix: Handle nil pointer in judgeApiWebhookUrl helper

## Usage

### Enable Vault Integration

In your values file:

```yaml
global:
  secrets:
    provider: "vault"
    vault:
      server: "https://vault.testifysec-demo.xyz"
      path: "secret"
      version: "v2"
      authMountPath: "kubernetes"

# Configure Vault roles for each service
kratos:
  vault:
    enabled: false  # Using ESO instead of Vault Agent injection
    role: "kratos"  # Vault Kubernetes auth role name
  serviceAccount:
    create: true
    name: "kratos"

judge-api:
  vault:
    enabled: false
    role: "judge-api"
  serviceAccount:
    create: true
    name: "judge-api"

archivista:
  vault:
    enabled: false
    role: "archivista"
  serviceAccount:
    create: true
    name: "archivista"
```

## Prerequisites

### 1. External Secrets Operator
```bash
helm repo add external-secrets https://charts.external-secrets.io
helm install external-secrets external-secrets/external-secrets -n external-secrets-system --create-namespace
```

### 2. Vault Configuration (Terraform)

Vault must be configured with:
- **Kubernetes Auth Method**: Mounted at `/auth/kubernetes`
- **Kubernetes Auth Roles**: `judge-api`, `archivista`, `kratos`
- **Policies**: Grant read access to secret paths
- **Database Secrets Engine**: For dynamic credentials (optional)
- **KV v2 Secrets Engine**: Mounted at `/secret`

Example Terraform: See `cust-anaconda-terraform-aws/modules/vault-config/`

### 3. Service Accounts

Each service requires a Kubernetes ServiceAccount that matches the Vault role:
- `kratos` ServiceAccount → `kratos` Vault role
- `judge-api` ServiceAccount → `judge-api` Vault role
- `archivista` ServiceAccount → `archivista` Vault role

## Vault Secret Paths

### Dynamic Database Credentials
- `database/creds/judge-api` - PostgreSQL credentials for Judge API
- `database/creds/archivista` - PostgreSQL credentials for Archivista

### Static Application Secrets (KV v2)
- `secret/data/demo/kubernetes/rds/testifysec-judge` - Database DSN
- `secret/data/demo/kubernetes/app/testifysec-judge` - OIDC, cookies, cipher keys

## Testing

### Verify SecretStores
```bash
kubectl get secretstore -n judge
kubectl describe secretstore vault-kratos -n judge
```

### Verify ExternalSecrets
```bash
kubectl get externalsecret -n judge
kubectl describe externalsecret kratos -n judge
```

### Verify Synced Secrets
```bash
kubectl get secret -n judge | grep judge
kubectl get secret kratos -n judge -o yaml
```

## Critical Configuration Requirements

### 1. Separate Databases (CRITICAL)
**Problem**: Shared database causes "migration files added out of order" error

Each Judge service MUST have its own PostgreSQL database:
- `judge_api` - Judge API artifact metadata
- `archivista` - Attestation metadata
- `kratos` - Identity and session data

**Why**: Atlas uses hash-based migration tracking in `atlas_schema_revisions` table. Shared database causes conflicts between services.

### 2. AWS Resource Naming (CRITICAL)
**All AWS resources use `demo-judge-` prefix, NOT `prod-` prefix**

- **S3 Buckets**:
  - `demo-judge-judge` - Judge API artifacts
  - `demo-judge-archivista` - Archivista attestations
- **IAM Roles**:
  - `demo-judge-judge-api`
  - `demo-judge-archivista`
- **SNS/SQS**: `demo-judge-archivista-attestations`

**Root Cause**: Configuration must match actual AWS resource names or IRSA fails.

### 3. Kubernetes Service Names (CRITICAL)
**Pattern**: `{release-name}-{chart-name}` where release-name=`judge-platform`

- Judge API: `judge-platform-judge-api.judge.svc.cluster.local:8080`
- Archivista: `judge-platform-judge-archivista.judge.svc.cluster.local:8082`
- Gateway: `judge-platform-judge-gateway.judge.svc.cluster.local:4000`

**Root Cause**: Cannot use hypothetical names based on nameOverride. Must use actual K8s service DNS names for inter-service communication.

## AWS Environment

- **EKS Cluster**: `demo-judge` in AWS account `831646886084`
  - Region: `us-east-1`
  - AWS Profile: `conda-demo`
  - Kubectl context: `arn:aws:eks:us-east-1:831646886084:cluster/demo-judge`

- **RDS PostgreSQL**: `demo-judge-postgres.cenw4a6wen6f.us-east-1.rds.amazonaws.com`
  - Instance: PostgreSQL 16
  - Separate databases: judge_api, archivista, kratos
  - Vault path: `secret/demo/kubernetes/rds/testifysec-judge`

- **Deployment Status**:
  - ✅ judge-api v1.15.0 - Running
  - ✅ archivista v1.15.0 - Running
  - ✅ kratos v1.1.0-token-update - Running
  - ✅ All 9 services operational

## Development Practices

### Helm Dependency Management - CRITICAL FOR ARGOCD

**ALWAYS remember**: This repository uses `file://` relative path dependencies in `Chart.yaml`. These paths cannot be resolved by ArgoCD!

#### Root Cause of OutOfSync Issues

When you modify a subchart template (e.g., `charts/tsa/templates/tsa-configmap.yaml`):
1. Your local `helm template` renders the fix correctly
2. But ArgoCD uses **cached/stale chart versions** from when dependencies were last built
3. ArgoCD cannot resolve `file://../tsa` paths - it needs `Chart.lock` to have concrete chart versions
4. Result: Resources show `OutOfSync` despite your fixes being committed

#### Solution: Pre-Commit Hook

A pre-commit hook automatically rebuilds `Chart.lock` whenever `Chart.yaml` changes:

```bash
# Normal workflow - hook handles everything:
$ git add charts/judge/Chart.yaml
$ git commit -m "deps: update tsa version"
# → Hook runs: helm dependency build charts/judge
# → Hook updates: charts/judge/Chart.lock
# → Hook adds Chart.lock to commit
# ✅ Commit includes fresh Chart.lock with correct versions
```

#### Why This Matters for ArgoCD

- **Before**: ArgoCD renders with old TSA template → `OutOfSync`
- **After**: ArgoCD renders with new TSA template → `Synced`

The `Chart.lock` file is what tells ArgoCD which exact chart versions to use. Without it, ArgoCD can't resolve your local file dependencies.

#### If the Hook Doesn't Run

```bash
# Manual rebuild if needed
make deps
git add charts/*/Chart.lock
git commit -m "deps: rebuild chart dependencies"
```

#### Workflow Rules

✅ **DO**:
- Always commit `Chart.lock` when modifying subcharts
- Use `make deps` after any subchart template changes
- Let the pre-commit hook handle dependency rebuilds automatically

❌ **DON'T**:
- Modify `Chart.yaml` without rebuilding dependencies
- Forget to commit `Chart.lock` changes
- Expect ArgoCD to work with stale dependencies

### How to Debug Sync Issues

If a resource is `OutOfSync` after template changes:

1. **Verify Chart.lock is current**:
   ```bash
   make check-deps
   ```

2. **Check ArgoCD is using latest commit**:
   ```bash
   argocd app get judge-platform --show-operation | grep revision
   ```

3. **Verify template renders correctly locally**:
   ```bash
   helm template judge charts/judge -f values.yaml
   ```

4. **If still out of sync**: Delete and recreate the Application resource to force refresh

## Important Notes

- You must deploy via ArgoCD sync, debug the root cause of any sync issues
- External Secrets Operator manages all secrets from HashiCorp Vault
- IRSA (IAM Roles for Service Accounts) provides AWS permissions to pods
- Dapr pubsub enabled with SNS/SQS configuration
- MinIO is disabled (using S3 for object storage)
- MySQL is disabled (using RDS PostgreSQL)
- **Chart.lock must be committed** - it tells ArgoCD which chart versions to use
