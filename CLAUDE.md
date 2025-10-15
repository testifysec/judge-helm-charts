# Judge Helm Charts - ESO/Vault Integration (PR #1)

## Overview

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

## Related Repositories

- **Values Repository**: `testifysec/judge-platform-values` (private)
- **Terraform Infrastructure**: `cust-anaconda-terraform-aws` (private)
- **Customer Fork**: `testifysec/cust-anaconda-helm-charts` (reference)

## Working Directory

`/Users/nkennedy/proj/cust/conda/repos/judge-helm-charts`

## Git Remote

```bash
upstream    git@github.com:testifysec/judge-helm-charts.git
```
