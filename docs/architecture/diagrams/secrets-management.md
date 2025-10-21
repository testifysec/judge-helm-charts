# Secrets Management with External Secrets Operator and Vault

This diagram shows how secrets are managed using HashiCorp Vault and External Secrets Operator (ESO) in the Judge platform.

```mermaid
sequenceDiagram
    participant Pod as Application Pod<br/>(judge-api)
    participant SA as ServiceAccount<br/>(judge-api SA)
    participant ESO as External Secrets<br/>Operator
    participant K8s as Kubernetes API
    participant Vault as HashiCorp Vault
    participant VaultDB as Vault Database<br/>Secrets Engine
    participant RDS as AWS RDS<br/>(PostgreSQL)

    Note over Pod,RDS: 1. Initial Setup (Terraform)

    Vault->>Vault: Enable Kubernetes auth backend
    Vault->>Vault: Configure database secrets engine
    Vault->>Vault: Create policies (judge-api, archivista, etc.)
    Vault->>Vault: Create Kubernetes auth roles

    Note over Pod,RDS: 2. Runtime Secret Sync

    ESO->>K8s: Watch SecretStore resources
    ESO->>K8s: Watch ExternalSecret resources

    K8s->>ESO: ExternalSecret created<br/>(judge-api-database)

    ESO->>SA: Get ServiceAccount token
    SA-->>ESO: JWT token

    ESO->>Vault: Authenticate with JWT<br/>(Kubernetes auth backend)
    Note over Vault: Validates JWT signature<br/>Checks bound SA + namespace<br/>Returns Vault token

    Vault-->>ESO: Vault token + policies

    ESO->>Vault: Read secret<br/>(database/creds/judge-api)

    Vault->>VaultDB: Generate dynamic credentials
    VaultDB->>RDS: CREATE USER judge_api_xxx<br/>GRANT permissions
    RDS-->>VaultDB: User created
    VaultDB-->>Vault: Return credentials<br/>(username, password)

    Vault-->>ESO: Database credentials

    ESO->>K8s: Create/Update Secret<br/>(judge-judge-api-database)
    K8s-->>ESO: Secret created

    Note over Pod,RDS: 3. Application Usage

    Pod->>K8s: Mount Secret as env var<br/>or volume
    K8s-->>Pod: connectionString injected

    Pod->>RDS: Connect using<br/>dynamic credentials

    Note over Pod,RDS: 4. Credential Rotation

    Vault->>VaultDB: Credentials expiring<br/>(TTL: 24h)
    VaultDB->>RDS: REVOKE user<br/>judge_api_xxx

    ESO->>Vault: Refresh secret<br/>(periodic sync: 1h)
    Vault->>VaultDB: Generate new credentials
    VaultDB->>RDS: CREATE USER judge_api_yyy
    ESO->>K8s: Update Secret

    Note over Pod: Pod restart triggered<br/>by secret change<br/>(deployment annotation)
```

## Secret Types Managed

### Database Credentials (Dynamic)
- **Path**: `database/creds/{role}`
- **Roles**: `judge-api`, `archivista`, `kratos`
- **TTL**: 24 hours
- **Rotation**: Automatic via Vault lease renewal
- **Storage**: ExternalSecret → Kubernetes Secret

### Application Secrets (Static)
- **Path**: `secret/data/{env}/kubernetes/app/testifysec-judge`
- **Keys**:
  - OIDC client secrets (GitHub, GitLab, etc.)
  - Kratos secrets (cookie, cipher)
  - SMTP connection URI
- **Rotation**: Manual or via CI/CD
- **Storage**: ExternalSecret → Kubernetes Secret

## Authentication Flow

### Vault Kubernetes Auth Backend

```yaml
# ServiceAccount in pod
serviceAccountName: judge-api

# Vault Kubernetes auth role (configured in Terraform)
role: judge-api
bound_service_account_names: ["judge-api"]
bound_service_account_namespaces: ["judge"]
policies: ["judge-api"]
token_ttl: 86400  # 24 hours
```

### ESO SecretStore Configuration

```yaml
apiVersion: external-secrets.io/v1beta1
kind: SecretStore
metadata:
  name: vault
spec:
  provider:
    vault:
      server: "https://vault.example.com"
      path: "kubernetes"
      version: "v2"
      auth:
        kubernetes:
          mountPath: "kubernetes"
          role: "judge-api"
          serviceAccountRef:
            name: "judge-api"
```

### ESO ExternalSecret Configuration

```yaml
apiVersion: external-secrets.io/v1beta1
kind: ExternalSecret
metadata:
  name: judge-api-database
spec:
  refreshInterval: 1h
  secretStoreRef:
    name: vault
    kind: SecretStore
  target:
    name: judge-judge-api-database
    creationPolicy: Owner
  data:
  - secretKey: connectionString
    remoteRef:
      key: database/creds/judge-api
      property: connectionString
```

## Security Benefits

1. **No Static Credentials**: Database passwords generated dynamically
2. **Automatic Rotation**: Credentials expire after 24h TTL
3. **Least Privilege**: Each service has unique database user with minimal permissions
4. **Audit Trail**: All secret access logged in Vault
5. **Centralized Management**: Single source of truth for secrets
6. **Encryption at Rest**: Vault encrypts all secrets
7. **Fine-Grained Access**: Vault policies control who can read what

## Terraform Integration

All Vault configuration is managed via Terraform:
- Kubernetes auth backend setup
- Database secrets engine configuration
- Policy definitions
- Auth role bindings

See `examples/terraform/aws/` for complete Terraform modules.
