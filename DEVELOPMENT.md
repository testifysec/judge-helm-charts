# Judge Platform - Istio-Ready Helm Charts

This repository contains Helm charts for deploying the Judge platform with Istio service mesh support for customer environments.

## Purpose

Provide production-ready Helm charts with:
- **Istio compatibility**: Service port naming, sidecar injection control
- **Dapr + Istio coexistence**: Port exclusion annotations for workflows
- **Traffic management**: VirtualServices, Gateways for service mesh routing
- **mTLS enforcement**: Service-to-service authentication via Istio
- **Observability**: Distributed tracing and metrics via Istio telemetry
- **Vault PKI integration**: Certificate management for Fulcio and TSA

## URL Configuration Rules (CRITICAL)

### Kratos URLs
1. **Kratos `serve.public.base_url`**: MUST be external URL (`https://kratos.domain.xyz`)
   - Used for OAuth redirect URLs sent to browsers
   - Never use `cluster.local` - browsers cannot access internal DNS
   - Location: `charts/judge/templates/_helpers.tpl` → `judge.kratos.config.complete`

2. **Gateway Kratos URLs**: MUST include `http://` protocol
   - Format: `http://kratos-public.judge.svc.cluster.local`
   - Gateway code uses URLs as-is without modification
   - Location: `charts/judge/templates/_helpers.tpl` → `judge.gateway.kratosUrl`

3. **Judge-API Kratos URLs**: MUST NOT include protocol
   - Format: `kratos-public.judge.svc.cluster.local` (bare hostname)
   - Judge-API code internally prepends `http://` to hostnames
   - Adding `http://` causes double-prefixing: `http://http://...` → parse error
   - Location: `charts/judge-api/values.yaml` → `kratos.publicUrl`

### Common Mistakes
- ❌ Setting Kratos `base_url` to `cluster.local` → breaks OAuth
- ❌ Adding `http://` to judge-api Kratos URLs → parse errors
- ❌ Missing `http://` from gateway Kratos URLs → connection failures

## Upstream Reference

Based on `testifysec/judge/subtrees/charts` with Istio-specific modifications.

## Repository Structure

```
.
├── charts/
│   ├── judge/                    # Umbrella chart
│   │   ├── Chart.yaml           # Dependencies: archivista, judge-api, etc.
│   │   ├── values.yaml          # Global configuration
│   │   └── templates/
│   │       ├── gateway.yaml     # Istio Gateway
│   │       └── virtualservice.yaml
│   ├── archivista/              # Attestation storage service
│   │   └── templates/
│   │       └── deployment.yaml  # Dapr + Istio annotations
│   ├── judge-api/               # Core API service
│   ├── judge-web/               # Web UI
│   ├── fulcio/                  # Code signing CA
│   ├── tsa/                     # Timestamping Authority
│   ├── kratos/                  # Identity management
│   └── mysql/                   # Database (sidecar excluded)
└── istio/
    ├── gateway.yaml             # Shared Istio Gateway
    └── virtualservices/         # Per-service routing
```

## Key Modifications for Istio

### 1. Service Port Naming (Required for Protocol Detection)

**Before**:
```yaml
ports:
  - protocol: TCP
    port: 3306
    targetPort: 3306
```

**After**:
```yaml
ports:
  - name: tcp-mysql  # Istio detects MySQL protocol
    protocol: TCP
    port: 3306
    targetPort: 3306
```

### 2. Dapr + Istio Coexistence

**archivista/templates/deployment.yaml**:
```yaml
annotations:
  dapr.io/enabled: "true"
  dapr.io/app-id: "archivista"
  # Exclude Dapr ports from Istio sidecar
  traffic.sidecar.istio.io/excludeOutboundPorts: "50001,50002,9090"
  traffic.sidecar.istio.io/excludeInboundPorts: "50001,50002,9090"
```

### 3. MySQL Sidecar Exclusion

**mysql/templates/deployment.yaml**:
```yaml
annotations:
  sidecar.istio.io/inject: "false"  # MySQL protocol conflicts with Envoy
```

### 4. Istio Gateway Configuration

**judge/templates/gateway.yaml**:
```yaml
apiVersion: networking.istio.io/v1beta1
kind: Gateway
metadata:
  name: judge-gateway
spec:
  selector:
    istio: ingressgateway
  servers:
  - port:
      number: 443
      name: https
      protocol: HTTPS
    tls:
      mode: SIMPLE
      credentialName: judge-tls-cert
    hosts:
    - "*.{{ .Values.domain }}"
```

### 5. Vault Deployment (Transit API Only)

Vault is deployed in single-node standalone mode for demo purposes:
- **Purpose**: Transit API for future use (not database credentials)
- **Mode**: Standalone with file storage (not HA)
- **Agent Injection**: Disabled - not used for database credentials
- **Initialization**: Manual unseal required after deployment

## Configuration

### ECR Authentication

The Judge platform images are stored in an ECR registry. A Kubernetes secret named `regcred` provides authentication:

```bash
# Create the regcred secret (requires AWS credentials with ECR access)
ECR_PASSWORD=$(aws ecr get-login-password --region YOUR_REGION) && \
kubectl create secret docker-registry regcred \
  --namespace judge \
  --docker-server=YOUR_ACCOUNT_ID.dkr.ecr.YOUR_REGION.amazonaws.com \
  --docker-username=AWS \
  --docker-password="$ECR_PASSWORD"
```

This secret is referenced in your values file:
```yaml
global:
  imagePullSecrets:
    - name: regcred
```

### Database Configuration

Database credentials are managed via Kubernetes secrets created by Helm from connection strings.

#### Secrets File Pattern

Sensitive credentials are stored separately from the main values file:

**values.yaml** (committed to git):
```yaml
global:
  database:
    endpoint: your-rds-endpoint.region.rds.amazonaws.com
    username: postgres
  secrets:
    provider: k8s-secrets
    # Password configured in secrets.yaml (not committed)
```

**secrets.yaml** (gitignored):
```yaml
global:
  secrets:
    database:
      passwordEncoded: "YOUR_URL_ENCODED_DB_PASSWORD"
```

Deploy with both files:
```bash
helm install judge charts/judge -f values.yaml -f secrets.yaml
```

**Judge API:**
```yaml
judge-api:
  sqlStore:
    backend: psql
    connectionString: "postgresql://postgres:<url-encoded-password>@<rds-endpoint>:5432/postgres?sslmode=require"
    createSecret: true  # Helm creates K8s secret
  vault:
    enabled: false  # Not using Vault for database credentials
```

**Archivista:**
```yaml
archivista:
  sqlStore:
    backend: psql
    connectionString: "postgresql://postgres:<url-encoded-password>@<rds-endpoint>:5432/postgres?sslmode=require"
    createSecret: true  # Helm creates K8s secret
  vault:
    enabled: false  # Not using Vault for database credentials
```

**Note:** Vault is deployed for future use (transit API) but is NOT used for database credential management. All database credentials are managed via Kubernetes secrets.

## Helm Chart Improvements (2025-10-07)

A comprehensive refactoring was completed to simplify the `values-prod.yaml` file by moving repetitive template expressions into reusable helper functions.

### What Was Changed

**Phase 1: Connection String Helpers**
- Moved PostgreSQL DSN construction to helpers: `judge.rds.archivistaDsn`, `judge.rds.kratosDsn`, `judge.rds.judgeApiDsn`
- Eliminated 3 duplicate connection string templates
- Centralized RDS configuration (endpoint, port, username, password encoding)

**Phase 2: Domain URL Helpers**
- Created 5 domain URL helpers: `judge.url.kratos`, `judge.url.login`, `judge.url.judge`, `judge.url.wildcard`, `judge.url.root`
- Removed 19 inline template expressions from values file
- Single source of truth for domain configuration

**Phase 3: Image Tag Helpers**
- Added `judge.image.defaultTag` helper returning `global.version`
- Simplified image tag configuration: set `tag: ""` to use default
- All judge services (archivista, judge-api, judge-web, judge-gateway, judge-ai-proxy) use consistent versioning

**Phase 4: IAM Role ARN Helpers**
- Created `judge.iam.archivistaRole` and `judge.iam.judgeApiRole` helpers
- Documented expected IAM role naming convention: `{environment}-judge-{service}`
- Allows Terraform to align IAM role names to Helm expectations
- Uses `tpl` function in subchart serviceaccount templates to evaluate helper calls

**Phase 5: AWS Region Helper**
- Added `judge.aws.region` helper
- Replaced 3 region references in environment variables and Dapr config
- Centralized region configuration

### Results

**Before:** 25 template expressions in values-prod.yaml
**After:** 1 direct `.Values` reference (96% reduction)

**Benefits:**
- Single source of truth for infrastructure configuration
- Easier to maintain and understand
- Clear separation of configuration from construction logic
- Better alignment with Helm best practices
- Reduced cognitive load when reading values files

**Files Changed:**
- `charts/judge/templates/_helpers.tpl` - Added 12 helper functions
- `charts/judge/values-prod.yaml` - Replaced expressions with helper calls
- Subchart templates - Updated to use helpers via tpl function

**Commits:**
- d9e6946 - Phase 1: Connection string helpers
- acd0ce8 - Phase 2: Domain URL helpers
- abecb93 - Phase 3: Image tag helpers (fixed)
- 5b2e567 - Phase 4: IAM ARN helpers (fixed with tpl)
- a7a3011 - Phase 5: AWS Region helper + IAM role documentation

All changes should be verified through ArgoCD deployments to your cluster.

## Provider Backend Pattern (2025-10-08)

A major architectural refactoring implementing the Provider Backend Pattern for multi-cloud support. This enables the Judge platform to run on AWS, GCP, Azure, or local infrastructure with minimal configuration changes.

### Design Philosophy

Each resource type declares its **provider** with provider-specific config nested underneath. This creates a clear abstraction layer where:
- **Configuration** = What the customer changes (provider type, bucket names, etc.)
- **Derivation** = What helpers compute automatically (endpoints, connection strings, etc.)

### Provider Types

The platform distinguishes between **infrastructure providers** and **service providers**:

#### Infrastructure Provider (Special Case)
- **cloud**: Infrastructure metadata, not a service
  - Purpose: Account ID, default region, IAM/RBAC configuration
  - Examples: `aws`, `gcp`, `azure`, `local`
  - All services inherit `cloud.{provider}.region` but can override

#### Service Providers
- **registry**: Container image storage (`aws-ecr`, `gcp-artifact`, `azure-acr`, `docker-hub`, `local`)
- **database**: Persistent SQL storage (`aws-rds`, `gcp-cloudsql`, `azure-database`, `local-postgres`)
- **secrets**: Secret management (`k8s-secrets`, `vault`, `aws-secrets`, `gcp-secrets`, `azure-keyvault`)
- **storage**: Blob/object storage (`aws-s3`, `gcp-storage`, `azure-blob`, `minio`, `local`)
- **messaging**: Pub/sub queues (`aws-sns-sqs`, `gcp-pubsub`, `azure-servicebus`, `redis`, `kafka`)

### Example Structure

```yaml
global:
  # Deployment metadata (cloud-agnostic)
  domain: your-domain.com
  environment: production
  version: v1.15.0

  # Cloud infrastructure (infrastructure-level)
  cloud:
    provider: aws
    aws:
      accountId: "YOUR_AWS_ACCOUNT_ID"
      region: us-east-1  # Default for all services

  # Container registry (service-level)
  registry:
    provider: aws-ecr
    url: YOUR_ACCOUNT_ID.dkr.ecr.REGION.amazonaws.com
    repository: ""
    aws:
      region: us-east-1
      accountId: "YOUR_AWS_ACCOUNT_ID"

  # Database (service-level)
  database:
    provider: aws-rds
    type: postgresql
    port: 5432
    username: postgres
    aws:
      endpoint: demo-judge-postgres...
      region: us-east-1

  # Secrets management (service-level)
  secrets:
    provider: k8s-secrets
    database:
      passwordEncoded: "..."

  # Blob storage (service-level)
  storage:
    provider: aws-s3
    buckets:
      archivista: demo-judge-archivista
      judgeApi: demo-judge-judge
    aws:
      endpoint: s3.amazonaws.com
      region: us-east-1
      credentialType: IAM
      useTLS: true

  # Queue/Messaging (service-level)
  messaging:
    provider: aws-sns-sqs
    topics:
      archivistaAttestations: demo-judge-archivista-attestations
    aws:
      region: us-east-1
      snsTopicName: demo-judge-archivista-attestations
      sqsQueueName: demo-judge-archivista-attestations
```

### Migration Path

To switch from AWS to GCP, customers only need to:
1. Change provider values: `provider: aws-rds` → `provider: gcp-cloudsql`
2. Update provider-specific config under `gcp:` section
3. Helm helpers automatically generate correct endpoints and configuration

### Implementation Status

**Phase 1 (✅ Complete - commit 0d4b1ec):**
- Implemented provider pattern for: cloud, registry, database, secrets
- Updated 8 helper functions to use new paths
- Verified deployment: ArgoCD Synced/Healthy, all pods running
- No behavior change (AWS deployment identical)

**Phase 1.5 (🔄 Next):**
- Add storage and messaging providers
- Create helpers for blob storage configuration
- Create helpers for Dapr pubsub configuration
- Update environment variables to use new helpers

**Phase 2 (Planned):**
- Provider abstraction layer (e.g., `judge.database.endpoint` that works for any provider)
- Conditional logic for multiple provider support in helpers

**Phase 3 (Future):**
- Add GCP, Azure, and local provider support
- Document provider-specific requirements and limitations

### Benefits

✅ **Multi-cloud native**: Explicit provider declaration for each service
✅ **Secret manager abstraction**: Database passwords from Vault, AWS Secrets, or K8s
✅ **Clear migration path**: Change provider field to switch clouds
✅ **Self-documenting**: Comments show all supported providers
✅ **No parallel structures**: Single config for all providers
✅ **Incremental adoption**: Mix providers (AWS RDS + GCP Storage + Vault secrets)

### References

- **Issue**: #9 - Provider Backend Pattern implementation
- **Pattern precedent**: Terraform, Pulumi, Crossplane
- **Commit**: 0d4b1ec - Phase 1 implementation

## Relationship to Other Repos

1. **Deployed to**: `cust-anaconda-terraform-aws` (EKS cluster)
2. **Managed by**: `cust-anaconda-gitops` (ArgoCD applications)
3. **Linked to**: Epic #1947, Issue #1946 (Istio Service Mesh Testing)

## Deployment Workflow

```bash
# 1. Add Helm dependencies
helm dependency update charts/judge

# 2. Install to Istio-enabled cluster
helm install judge charts/judge \
  --namespace judge \
  --create-namespace \
  --values values-anaconda.yaml

# 3. Verify Istio injection
kubectl get pods -n judge -o jsonpath='{range .items[*]}{.metadata.name}{"\t"}{.spec.containers[*].name}{"\n"}{end}'
# Should show: judge-api, istio-proxy (sidecar)

# 4. Check VirtualService routing
kubectl get virtualservices -n judge
```

## GitOps Integration

ArgoCD Application referencing these charts:

```yaml
apiVersion: argoproj.io/v1alpha1
kind: Application
metadata:
  name: judge-anaconda
  namespace: argocd
spec:
  source:
    repoURL: https://github.com/testifysec/cust-anaconda-helm-charts
    targetRevision: main
    path: charts/judge
    helm:
      valueFiles:
      - values-production.yaml
  destination:
    server: https://kubernetes.default.svc
    namespace: judge
```

## Testing Checklist

- [ ] Service port naming compliant with Istio
- [ ] Dapr port exclusions configured
- [ ] MySQL sidecar injection disabled (not deployed - using RDS)
- [ ] Istio Gateway created
- [ ] VirtualServices route traffic correctly
- [ ] mTLS verified between services
- [ ] ECR authentication (regcred secret) working
- [ ] Database connections via K8s secrets working
- [ ] Distributed tracing works via Jaeger/Zipkin

## References

### Project Links
- **Epic**: testifysec/judge#1947
- **Related Issue**: testifysec/judge#1946 (Istio Service Mesh Testing)
- **Upstream Charts**: testifysec/judge (subtrees/charts)

### Official Documentation
- **Istio Application Requirements**: https://istio.io/latest/docs/ops/deployment/application-requirements/
- **Istio Gateway Configuration**: https://github.com/istio/istio/tree/master/manifests/charts/gateway
- **Istio VirtualService**: https://istio.io/latest/docs/reference/config/networking/virtual-service/
- **Dapr Sidecar Injector**: https://github.com/dapr/docs/blob/v1.16/daprdocs/content/en/concepts/dapr-services/sidecar-injector.md
- **Dapr + Service Mesh FAQ**: https://github.com/dapr/docs/blob/v1.16/daprdocs/content/en/concepts/faq/faq.md#how-does-dapr-compare-to-service-meshes-such-as-istio-linkerd-or-osm
- **Helm Best Practices**: https://helm.sh/docs/chart_best_practices/
- **Vault PKI Secrets Engine**: https://developer.hashicorp.com/vault/docs/secrets/pki

## Deployment Best Practices

- Helm is the source of truth - avoid direct kubectl modifications in production
- Test changes in dev/staging environments before production
- Use ArgoCD for GitOps-based deployments
- Always wait for ArgoCD to report healthy status before proceeding
- Terminate running syncs before starting new ones to avoid conflicts
- Use `helm test` to validate deployments
- Configure proper AWS credentials and kubectl context before deployment