# Judge Platform - Helm Charts

Deploy the complete Judge software supply chain security platform on AWS using Kubernetes and Helm.

## What is Judge?

Judge is a comprehensive software supply chain security platform that provides:
- **Artifact Attestation**: Cryptographically signed build provenance
- **Policy Enforcement**: Automated compliance verification for CI/CD pipelines
- **Vulnerability Management**: Supply chain risk assessment and reporting
- **Audit & Compliance**: Complete visibility into your software supply chain

## AWS Marketplace Deployment

These Helm charts are designed for AWS Marketplace customers deploying Judge on Amazon EKS. The charts provide production-ready configurations with smart defaults that work out-of-the-box with AWS services.

**Prerequisites:**
- Active AWS Marketplace subscription for Judge
- Amazon EKS cluster (Kubernetes 1.24+)
- Helm 3.8+
- AWS CLI configured with appropriate permissions
- Istio 1.18+ installed on your cluster

---

## Quick Start

### 1. Minimal Configuration

Create a `values.yaml` file with your AWS-specific settings:

```yaml
# values.yaml - Minimal configuration for AWS Marketplace deployment
global:
  domain: example.com
  aws:
    enabled: true
    accountId: "YOUR_AWS_ACCOUNT_ID"
    region: "us-east-1"
    prefix: "prod-judge"
    irsa:
      enabled: true
  registry:
    marketplace:
      enabled: true
  secrets:
    provider: "vault"
    vault:
      server: "https://vault.example.com"
      env: "prod"
      project: "mycompany-judge"

istio:
  enabled: true
  domain: example.com
  tlsSecretName: wildcard-tls
  hosts:
    web: "judge"
    api: "api"
    login: "login"
```

See [Global Configuration Reference](#global-configuration-reference) for detailed explanation of all fields.

### 2. Install Chart

```bash
# Clone the repository
git clone https://github.com/testifysec/judge-helm-charts.git
cd judge-helm-charts

# Build Helm dependencies
make deps

# Install Judge platform
helm install judge-platform charts/judge \
  --namespace judge \
  --create-namespace \
  --values values.yaml

# Verify deployment
kubectl get pods -n judge
kubectl get virtualservices -n judge
```

### 3. Access Services

After deployment, services are accessible via Istio ingress:

```bash
# Get ingress gateway external IP
kubectl get svc -n istio-system istio-ingressgateway

# Access services (replace with your domain)
https://judge.example.com       # Web UI
https://api.example.com          # API
https://login.example.com        # Authentication
```

---

## Global Configuration Reference

All Judge platform settings are configured through `global` values. These provide smart defaults and can be overridden as needed.

### Domain & Networking

```yaml
global:
  # Base domain for all external service URLs
  # Used for Istio VirtualServices, OIDC redirects, browser URLs
  domain: example.com
```

**Note**: Internal service-to-service communication uses Kubernetes DNS (`.svc.cluster.local`) automatically. For hostname customization, see [Istio Service Mesh Configuration](#istio-service-mesh-configuration).

### AWS Infrastructure Configuration

```yaml
global:
  aws:
    enabled: true                          # Enable AWS integrations
    accountId: "123456789012"             # Your 12-digit AWS account ID
    region: "us-east-1"                   # AWS region for all resources
    prefix: "prod-judge"                  # Resource naming prefix

    # IAM Roles for Service Accounts (IRSA)
    irsa:
      enabled: true                        # Adds IAM role annotations to ServiceAccounts
```

#### Resource Naming Convention

The `prefix` field is used to construct all AWS resource names. This MUST match your EKS cluster name to avoid conflicts.

**Pattern**: `{prefix}-{service}`

| Service | Resource Type | Name Example |
|---------|---------------|--------------|
| Judge API | S3 Bucket | `prod-judge-judge` |
| Judge API | IAM Role | `prod-judge-judge-api` |
| Archivista | S3 Bucket | `prod-judge-archivista` |
| Archivista | IAM Role | `prod-judge-archivista` |
| Messaging | SNS Topic | `prod-judge-archivista-attestations` |
| Messaging | SQS Queue | `prod-judge-archivista-attestations` |

**Examples**:
- `prefix: "demo-judge"` → Cluster: `demo-judge`, S3: `demo-judge-judge`, IAM: `demo-judge-judge-api`
- `prefix: "prod-judge"` → Cluster: `prod-judge`, S3: `prod-judge-judge`, IAM: `prod-judge-judge-api`

### Version Management

```yaml
global:
  versions:
    platform: "v1.15.0"                   # Default version for all Judge services

    # Individual service overrides (optional)
    api: ""                               # Leave empty to use platform version
    archivista: ""
    gateway: ""
    web: ""

    # Supporting services (specify explicit versions)
    dex: "v2.43.1"                        # OIDC provider
    fulcio: "v1.4.5"                      # Code signing CA
    tsa: "v1.6.0"                         # Timestamping authority
    kratos: "v1.0.0"                      # Identity service
    kratosUI: "v1.6.0"                    # Login UI
```

**Behavior**:
- Services use `versions.platform` by default
- Override individual services only when needed (e.g., testing new API version)
- Supporting services must specify explicit versions

### Istio Service Mesh Configuration

```yaml
# Root-level istio configuration (can also be set via global.istio)
istio:
  enabled: true
  domain: example.com                      # MUST match global.domain
  tlsSecretName: wildcard-tls             # Kubernetes secret with TLS certificate

  # Ingress gateway selector (must match Istio gateway pod labels)
  ingressGatewaySelector:
    istio: ingress

  # Hostname customization (subdomain prefixes only)
  hosts:
    web: "judge"                           # Results in: judge.example.com
    api: "api"                             # Results in: api.example.com
    gateway: "gateway"                     # Results in: gateway.example.com
    login: "login"                         # Results in: login.example.com
    kratos: "kratos"                       # Results in: kratos.example.com
    dex: "dex"                             # Results in: dex.example.com
    fulcio: "fulcio"                       # Results in: fulcio.example.com
    tsa: "tsa"                             # Results in: tsa.example.com
```

**Customization Example**:
```yaml
istio:
  domain: mycompany.com
  hosts:
    web: "supply-chain"                    # supply-chain.mycompany.com
    api: "supply-chain-api"                # supply-chain-api.mycompany.com
```

### Development Mode

```yaml
global:
  mode: aws                                # Options: aws | dev

  # Use mode: dev for local testing without AWS dependencies
  # Deploys LocalStack (S3 emulation) + PostgreSQL in-cluster
```

**Mode Comparison**:

| Feature | `aws` Mode | `dev` Mode |
|---------|-----------|------------|
| Database | AWS RDS | In-cluster PostgreSQL |
| Storage | AWS S3 | LocalStack S3 emulation |
| Messaging | AWS SNS/SQS | LocalStack SNS/SQS |
| Secrets | Vault + ESO | Kubernetes Secrets |
| IRSA | Enabled | Disabled |
| **Use Case** | Production AWS deployment | Local development/testing |

---

## Infrastructure & AWS Resources

### Required AWS Resources

Before deploying Judge, provision these AWS resources (typically via Terraform):

#### 1. **Amazon RDS PostgreSQL Database**

**Requirements**:
- PostgreSQL 13+
- Three separate databases on one instance:
  ```sql
  CREATE DATABASE judge_api;
  CREATE DATABASE archivista;
  CREATE DATABASE kratos;
  ```
- SSL/TLS enabled (`sslmode=require`)

**Configuration**:
```yaml
# Connection strings stored in Vault
# Path: {env}/kubernetes/rds/{project}
# Keys:
#   - judge_api_dsn: postgres://user:pass@endpoint:5432/judge_api?sslmode=require
#   - archivista_dsn: postgres://user:pass@endpoint:5432/archivista?sslmode=require
#   - kratos_dsn: postgres://user:pass@endpoint:5432/kratos?sslmode=require
```

#### 2. **S3 Buckets for Storage**

**Buckets** (named using `{prefix}-{service}` pattern):
- `{prefix}-judge` - Judge API artifact storage
- `{prefix}-archivista` - Attestation storage

**Configuration**:
```yaml
global:
  aws:
    prefix: "prod-judge"                   # Creates: prod-judge-judge, prod-judge-archivista
    s3:
      enabled: true
      judge:
        bucket: "prod-judge-judge"
        region: "us-east-1"
      archivista:
        bucket: "prod-judge-archivista"
        region: "us-east-1"
```

#### 3. **SNS Topic & SQS Queue for Messaging**

**Resources** (named using `{prefix}-{service}` pattern):
- SNS Topic: `{prefix}-archivista-attestations`
- SQS Queue: `{prefix}-archivista-attestations`

**Configuration**:
```yaml
global:
  aws:
    messaging:
      enabled: true
      snsTopic: "prod-judge-archivista-attestations"
      sqsQueue: "prod-judge-archivista-attestations"
      region: "us-east-1"
```

#### 4. **IAM Roles for IRSA**

**Roles** (named using `{prefix}-{service}` pattern):
- `{prefix}-judge-api` - S3 read/write for judge bucket
- `{prefix}-archivista` - S3 read/write for archivista bucket, SNS/SQS publish/subscribe
- `{prefix}-kratos` - (optional) additional permissions if needed

**Trust Policy** (Kubernetes ServiceAccount → IAM Role):
```json
{
  "Version": "2012-10-17",
  "Statement": [{
    "Effect": "Allow",
    "Principal": {
      "Federated": "arn:aws:iam::{account-id}:oidc-provider/{oidc-provider}"
    },
    "Action": "sts:AssumeRoleWithWebIdentity",
    "Condition": {
      "StringEquals": {
        "{oidc-provider}:sub": "system:serviceaccount:judge:{release-name}-judge-api"
      }
    }
  }]
}
```

**IAM Permissions Example** (Judge API):
```json
{
  "Version": "2012-10-17",
  "Statement": [
    {
      "Effect": "Allow",
      "Action": [
        "s3:PutObject",
        "s3:GetObject",
        "s3:DeleteObject"
      ],
      "Resource": "arn:aws:s3:::prod-judge-judge/*"
    },
    {
      "Effect": "Allow",
      "Action": "s3:ListBucket",
      "Resource": "arn:aws:s3:::prod-judge-judge"
    }
  ]
}
```

### Kubernetes ServiceAccount Naming

Judge creates Kubernetes ServiceAccounts using this pattern: `{release-name}-{service}`

**Examples**:
- Helm release: `judge-platform`
  - Judge API ServiceAccount: `judge-platform-judge-api`
  - Archivista ServiceAccount: `judge-platform-judge-archivista`
  - Kratos ServiceAccount: `judge-platform-judge-kratos`

- Helm release: `prod-judge`
  - Judge API ServiceAccount: `prod-judge-judge-api`
  - Archivista ServiceAccount: `prod-judge-judge-archivista`

**IRSA Annotation** (added automatically when `global.aws.irsa.enabled: true`):
```yaml
apiVersion: v1
kind: ServiceAccount
metadata:
  name: judge-platform-judge-api
  annotations:
    eks.amazonaws.com/role-arn: arn:aws:iam::123456789012:role/prod-judge-judge-api
```

---

## Secrets Management

Judge uses External Secrets Operator (ESO) + HashiCorp Vault for secure, dynamic secret management.

### Configuration

```yaml
global:
  secrets:
    provider: "vault"                      # Secret backend (vault is default)
    vault:
      server: "https://vault.example.com"  # Vault server URL
      path: "secret"                       # KV v2 mount path (default: secret)
      version: "v2"                        # KV version (v1 or v2)
      authMountPath: "kubernetes"          # Kubernetes auth backend mount
      env: "prod"                          # Environment: dev, staging, prod
      project: "mycompany-judge"           # Project identifier

      # ServiceAccount names for Vault Kubernetes authentication
      # These MUST match the actual Kubernetes ServiceAccount names
      # Default: Leave empty to auto-compute from release name
      serviceAccounts:
        judgeApi: ""                       # Auto: {release-name}-judge-api
        archivista: ""                     # Auto: {release-name}-judge-archivista
        kratos: ""                         # Auto: {release-name}-judge-kratos
```

### Vault Path Structure

Secrets are organized using this pattern: `{env}/kubernetes/{type}/{project}`

**Examples**:
- Production database: `prod/kubernetes/rds/mycompany-judge`
- Staging application: `staging/kubernetes/app/mycompany-judge`
- Development database: `dev/kubernetes/rds/mycompany-judge`

### Required Secrets

#### 1. Database Credentials

**Vault Path**: `{env}/kubernetes/rds/{project}`

**Keys**:
```yaml
judge_api_dsn: "postgres://user:password@endpoint:5432/judge_api?sslmode=require"
archivista_dsn: "postgres://user:password@endpoint:5432/archivista?sslmode=require"
kratos_dsn: "postgres://user:password@endpoint:5432/kratos?sslmode=require"
```

**Vault CLI Example**:
```bash
vault kv put secret/prod/kubernetes/rds/mycompany-judge \
  judge_api_dsn="postgres://judgeuser:SecurePass123@prod-db.us-east-1.rds.amazonaws.com:5432/judge_api?sslmode=require" \
  archivista_dsn="postgres://archivistauser:SecurePass456@prod-db.us-east-1.rds.amazonaws.com:5432/archivista?sslmode=require" \
  kratos_dsn="postgres://kratosuser:SecurePass789@prod-db.us-east-1.rds.amazonaws.com:5432/kratos?sslmode=require"
```

#### 2. Application Secrets

**Vault Path**: `{env}/kubernetes/app/{project}`

**Keys**:
```yaml
kratos_secrets_cookie: "32-byte-random-string-base64"     # Cookie encryption key
kratos_secrets_cipher: "32-byte-random-string-base64"     # Data encryption key
oidc_github_client_id: "your-github-oauth-app-id"         # GitHub OAuth client ID
oidc_github_client_secret: "your-github-oauth-secret"     # GitHub OAuth secret
```

**Generate Secrets**:
```bash
# Generate random encryption keys
COOKIE_SECRET=$(openssl rand -base64 32)
CIPHER_SECRET=$(openssl rand -base64 32)

# Store in Vault
vault kv put secret/prod/kubernetes/app/mycompany-judge \
  kratos_secrets_cookie="$COOKIE_SECRET" \
  kratos_secrets_cipher="$CIPHER_SECRET" \
  oidc_github_client_id="Iv1.your-github-client-id" \
  oidc_github_client_secret="ghp_your-github-client-secret"
```

### Vault Kubernetes Authentication Setup

Judge requires Vault Kubernetes auth roles for each service. These roles bind ServiceAccounts to Vault policies.

**Prerequisites**:
- Vault Kubernetes auth method enabled
- Kubernetes cluster configured in Vault
- Vault policies created for each service

**Example Terraform Configuration**:
```hcl
# Vault Kubernetes auth role for Judge API
resource "vault_kubernetes_auth_backend_role" "judge_api" {
  backend                          = "kubernetes"
  role_name                        = "judge-api"
  bound_service_account_names      = ["judge-platform-judge-api"]
  bound_service_account_namespaces = ["judge"]
  token_ttl                        = 3600
  token_policies                   = ["judge-api-policy"]
}

# Vault policy for Judge API
resource "vault_policy" "judge_api" {
  name   = "judge-api-policy"
  policy = <<EOT
path "secret/data/prod/kubernetes/rds/mycompany-judge" {
  capabilities = ["read"]
}
EOT
}
```

**Repeat for archivista and kratos** with their respective ServiceAccount names.

---

## Container Registry Configuration

### AWS Marketplace Registry (Default)

Judge is distributed via AWS Marketplace using a shared ECR registry. This is enabled by default.

```yaml
global:
  registry:
    marketplace:
      enabled: true                        # Uses AWS Marketplace ECR (709825985650)
```

**Registry Details**:
- **Account**: `709825985650` (AWS Marketplace official)
- **Region**: `us-east-1` (hardcoded)
- **Seller Namespace**: `testifysec` (hardcoded)
- **Image Path Pattern**: `709825985650.dkr.ecr.us-east-1.amazonaws.com/testifysec/{image}:{tag}`

**Authentication**:
- Requires active AWS Marketplace subscription
- Node IAM role automatically authenticates to marketplace ECR
- No additional image pull secrets required

**Available Images**:
- `testifysec/judge-api:{version}`
- `testifysec/judge-web:{version}`
- `testifysec/judge-archivista:{version}`
- `testifysec/judge-dex:{version}`
- `testifysec/judge-fulcio:{version}`
- `testifysec/judge-kratos:{version}`
- `testifysec/judge-kratos-self-service:{version}`
- `testifysec/judge-timestamp-server:{version}`

### Custom Registry (Alternative)

For private registries or self-hosted deployments:

```yaml
global:
  registry:
    marketplace:
      enabled: false                       # Disable marketplace ECR
    url: "myregistry.example.com"         # Your registry URL
    repository: "myorg"                    # Repository namespace

  imagePullSecrets:                        # Optional: registry authentication
    - name: my-registry-secret
```

**Image Path Pattern**: `{url}/{repository}/{image}:{tag}`

**Example**: `myregistry.example.com/myorg/judge-api:v1.15.0`

### Version Overrides

Override specific service versions:

```yaml
global:
  versions:
    platform: "v1.15.0"                    # Default for all services
    api: "v1.16.0-beta"                    # Test new API version

  registry:
    marketplace:
      enabled: true
      versions:                            # Per-service version overrides
        dex: "v2.43.2"                     # Use newer Dex version
```

---

## Common Configuration Overrides

### Resource Limits

Configure CPU and memory for production workloads:

```yaml
judge-api:
  resources:
    requests:
      memory: "1Gi"
      cpu: "500m"
    limits:
      memory: "2Gi"
      cpu: "1000m"

archivista:
  resources:
    requests:
      memory: "512Mi"
      cpu: "250m"
    limits:
      memory: "1Gi"
      cpu: "500m"
```

### High Availability

Scale replicas for critical services:

```yaml
judge-api:
  replicaCount: 3

archivista:
  replicaCount: 3

kratos:
  kratos:
    replicaCount: 2
```

### Feature Flags

Enable or disable platform features:

```yaml
# Disable code signing and timestamping (not yet integrated with CI/CD)
fulcio:
  enabled: false

tsa:
  enabled: false

# Disable AI proxy if not using AI-powered features
judge-ai-proxy:
  enabled: false

# Disable OIDC if using only password authentication
global:
  oidc:
    enabled: false
```

### ArgoCD Integration

Enable when deploying via ArgoCD:

```yaml
global:
  argocd:
    enabled: true                          # Adds sync annotations to Jobs
```

---

## Deployment Validation

### Verify Installation

```bash
# Check all pods are running
kubectl get pods -n judge

# Expected output: All pods in Running status
# NAME                                                    READY   STATUS
# judge-platform-judge-api-xxxx                          1/1     Running
# judge-platform-judge-archivista-xxxx                   1/1     Running
# judge-platform-judge-web-xxxx                          1/1     Running
# judge-platform-judge-gateway-xxxx                      1/1     Running
# judge-platform-judge-kratos-xxxx                       1/1     Running
# judge-platform-judge-kratos-self-service-xxxx          1/1     Running
# judge-platform-judge-dex-xxxx                          1/1     Running
```

### Verify Istio VirtualServices

```bash
# Check VirtualServices are created
kubectl get virtualservices -n judge

# Expected: One VirtualService per public-facing service
# NAME                    GATEWAYS                    HOSTS
# judge-api-vs            ["judge-gateway"]          ["api.example.com"]
# judge-web-vs            ["judge-gateway"]          ["judge.example.com"]
# kratos-public-vs        ["judge-gateway"]          ["kratos.example.com"]
```

### Verify External Secrets

```bash
# Check ExternalSecrets are synced
kubectl get externalsecrets -n judge

# Expected: All ExternalSecrets show "SecretSynced" status
# NAME                              STATUS           LAST REFRESH
# judge-archivista-database         SecretSynced     1m
# judge-api-database                SecretSynced     1m
# judge-kratos                      SecretSynced     1m
```

### Verify IRSA Configuration

```bash
# Check ServiceAccount has IAM role annotation
kubectl get serviceaccount judge-platform-judge-api -n judge -o yaml

# Expected annotation:
# annotations:
#   eks.amazonaws.com/role-arn: arn:aws:iam::123456789012:role/prod-judge-judge-api
```

### Test Service Access

```bash
# Get ingress gateway external IP/hostname
kubectl get svc -n istio-system istio-ingressgateway

# Test web UI access
curl -k https://judge.example.com

# Test API health endpoint
curl -k https://api.example.com/health
```

---

## Troubleshooting

### Common Issues

#### 1. ImagePullBackOff Errors

**Symptom**: Pods stuck in `ImagePullBackOff`

**Causes**:
- No active AWS Marketplace subscription
- Node IAM role missing ECR permissions
- Wrong registry configuration

**Solution**:
```bash
# Verify marketplace subscription in AWS Console
# AWS Marketplace → Manage subscriptions → Judge

# Check node IAM role has ECR permissions
aws iam get-role-policy \
  --role-name {eks-node-role} \
  --policy-name ECRReadOnly

# Verify registry configuration
kubectl get pods -n judge -o yaml | grep "image:"
```

#### 2. ExternalSecret Not Syncing

**Symptom**: `kubectl get externalsecrets` shows `SyncError`

**Causes**:
- Vault not reachable from cluster
- Vault Kubernetes auth not configured
- ServiceAccount names mismatch
- Missing secrets in Vault

**Solution**:
```bash
# Check ExternalSecret status
kubectl describe externalsecret judge-api-database -n judge

# Verify Vault connectivity
kubectl run vault-test --rm -it --image=curlimages/curl -- \
  curl -k https://vault.example.com/v1/sys/health

# Verify Vault Kubernetes auth role
vault read auth/kubernetes/role/judge-api

# Check Vault secrets exist
vault kv get secret/prod/kubernetes/rds/mycompany-judge
```

#### 3. IRSA Not Working

**Symptom**: Pods can't access S3/SNS/SQS with permission denied errors

**Causes**:
- IAM role trust policy incorrect
- ServiceAccount annotation missing
- IAM role permissions insufficient

**Solution**:
```bash
# Verify ServiceAccount has correct annotation
kubectl get sa judge-platform-judge-api -n judge -o jsonpath='{.metadata.annotations}'

# Check IAM role trust policy allows ServiceAccount
aws iam get-role --role-name prod-judge-judge-api --query 'Role.AssumeRolePolicyDocument'

# Test IAM role from pod
kubectl exec -it {judge-api-pod} -n judge -- \
  aws sts get-caller-identity
```

#### 4. Database Connection Failures

**Symptom**: Pods crash with database connection errors

**Causes**:
- RDS security group doesn't allow EKS pods
- Database credentials incorrect
- Database doesn't exist
- SSL/TLS configuration mismatch

**Solution**:
```bash
# Verify RDS security group allows EKS CIDR
aws ec2 describe-security-groups \
  --group-ids {rds-security-group-id}

# Test database connectivity from cluster
kubectl run psql-test --rm -it --image=postgres:13 -- \
  psql "postgres://user:pass@endpoint:5432/judge_api?sslmode=require"

# Check database secret in Kubernetes
kubectl get secret judge-api-database -n judge -o yaml
```

---

## Advanced Configuration

### TLS Certificate Management

Judge requires TLS certificates for HTTPS access via Istio ingress.

**Option 1: cert-manager (Recommended)**:
```yaml
# Install cert-manager first
# helm install cert-manager jetstack/cert-manager ...

# Configure ClusterIssuer
apiVersion: cert-manager.io/v1
kind: ClusterIssuer
metadata:
  name: letsencrypt-prod
spec:
  acme:
    server: https://acme-v02.api.letsencrypt.org/directory
    email: admin@example.com
    privateKeySecretRef:
      name: letsencrypt-prod
    solvers:
    - http01:
        ingress:
          class: istio

# Reference in values.yaml
istio:
  tlsSecretName: wildcard-tls              # Created by cert-manager
```

**Option 2: Manual Certificate**:
```bash
# Create TLS secret manually
kubectl create secret tls wildcard-tls \
  --cert=tls.crt \
  --key=tls.key \
  -n judge
```

### Multi-Environment Deployments

Deploy multiple Judge instances (dev, staging, prod) in the same cluster:

```yaml
# values-dev.yaml
global:
  domain: dev.example.com
  aws:
    prefix: "dev-judge"
  secrets:
    vault:
      env: "dev"

# values-staging.yaml
global:
  domain: staging.example.com
  aws:
    prefix: "staging-judge"
  secrets:
    vault:
      env: "staging"

# values-prod.yaml
global:
  domain: example.com
  aws:
    prefix: "prod-judge"
  secrets:
    vault:
      env: "prod"
```

Install with different release names and namespaces:
```bash
helm install judge-dev charts/judge -n judge-dev --values values-dev.yaml
helm install judge-staging charts/judge -n judge-staging --values values-staging.yaml
helm install judge-prod charts/judge -n judge-prod --values values-prod.yaml
```

---

## Support & Additional Resources

### Documentation

- **Architecture Diagrams**: [docs/architecture/diagrams/](docs/architecture/diagrams/)
- **Deployment Guides**: [docs/deployment/](docs/deployment/)
- **Configuration Reference**: [charts/judge/docs/](charts/judge/docs/)
- **Development Guide**: [DEVELOPMENT.md](DEVELOPMENT.md)
- **Contributing**: [CONTRIBUTING.md](CONTRIBUTING.md)

### Terraform Examples

Complete infrastructure-as-code examples for AWS:
- [examples/terraform/aws/complete/](examples/terraform/aws/complete/)

Includes:
- EKS cluster with IRSA
- RDS PostgreSQL database
- S3 buckets
- SNS/SQS messaging
- Vault configuration
- IAM roles and policies

### External References

- [Istio Documentation](https://istio.io/latest/docs/)
- [External Secrets Operator](https://external-secrets.io/)
- [HashiCorp Vault Kubernetes Auth](https://www.vaultproject.io/docs/auth/kubernetes)
- [AWS EKS IRSA](https://docs.aws.amazon.com/eks/latest/userguide/iam-roles-for-service-accounts.html)
- [Helm Best Practices](https://helm.sh/docs/chart_best_practices/)

### Getting Help

For support, questions, or issues:
1. Check [Troubleshooting](#troubleshooting) section above
2. Review [GitHub Issues](https://github.com/testifysec/judge-helm-charts/issues)
3. Contact TestifySec support via AWS Marketplace support channel
4. Email: support@testifysec.com

---

## License

Copyright © TestifySec. All rights reserved.

Proprietary software distributed via AWS Marketplace. See AWS Marketplace listing for license terms and conditions.
