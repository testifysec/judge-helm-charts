# Deployment Pipeline and GitOps Workflow

This diagram shows the end-to-end deployment process for the Judge platform using Terraform, ArgoCD, and GitOps principles.

```mermaid
graph TB
    subgraph "Development"
        Dev[Developer] -->|Commits code| GitRepo[Git Repository]
        Dev -->|Updates values| HelmRepo[Helm Charts Repo]
    end

    subgraph "Phase 1: Infrastructure Provisioning (Terraform)"
        TF_Plan[terraform plan<br/>Validate changes]
        TF_Apply[terraform apply<br/>Provision infrastructure]

        GitRepo -->|Triggers| TF_Plan
        TF_Plan -->|Review & Approve| TF_Apply

        TF_Apply -->|Creates| EKS[EKS Cluster<br/>VPC, Subnets, NAT]
        TF_Apply -->|Creates| RDS[RDS PostgreSQL<br/>Multi-AZ]
        TF_Apply -->|Creates| S3[S3 Buckets<br/>Versioned, Encrypted]
        TF_Apply -->|Creates| IAM[IAM Roles<br/>IRSA for pods]
        TF_Apply -->|Creates| SNS[SNS/SQS<br/>Messaging]
        TF_Apply -->|Deploys| ESO_Helm[External Secrets<br/>Operator via Helm]
        TF_Apply -->|Configures| Vault_Setup[Vault Configuration<br/>K8s auth, DB engine]
    end

    subgraph "Phase 2: Secret Management Setup"
        Vault_Setup -->|Enables| Vault_K8s[Vault Kubernetes<br/>Auth Backend]
        Vault_Setup -->|Configures| Vault_DB[Vault Database<br/>Secrets Engine]
        Vault_Setup -->|Creates| Vault_Policies[Vault Policies<br/>judge-api, archivista]
        Vault_Setup -->|Creates| Vault_Roles[Vault Auth Roles<br/>SA bindings]
    end

    subgraph "Phase 3: ArgoCD Application Deployment"
        HelmRepo -->|Syncs| ArgoCD[ArgoCD Controller<br/>Monitors Git]

        ArgoCD -->|Creates| App[ArgoCD Application<br/>judge-platform]
        App -->|Renders| Helm[Helm Chart<br/>judge]

        Helm -->|Deploys| K8s_Resources[Kubernetes Resources]

        K8s_Resources -->|Creates| Deployments[Deployments<br/>judge-api, archivista, etc.]
        K8s_Resources -->|Creates| Services[Services<br/>ClusterIP, LoadBalancer]
        K8s_Resources -->|Creates| ConfigMaps[ConfigMaps<br/>Application config]
        K8s_Resources -->|Creates| ExternalSecrets[ExternalSecrets<br/>Database creds, OIDC]
        K8s_Resources -->|Creates| VirtualServices[Istio VirtualServices<br/>Routing rules]
    end

    subgraph "Phase 4: Secret Synchronization"
        ExternalSecrets -->|Triggers| ESO_Controller[ESO Controller<br/>Watches resources]

        ESO_Controller -->|Authenticates| Vault_K8s
        ESO_Controller -->|Reads| Vault_DB
        ESO_Controller -->|Creates| K8s_Secrets[Kubernetes Secrets<br/>Managed by ESO]
    end

    subgraph "Phase 5: Pod Startup"
        Deployments -->|Creates| Pods[Application Pods]
        K8s_Secrets -->|Mounts| Pods
        ConfigMaps -->|Mounts| Pods

        Pods -->|Injects| Istio_Sidecar[Istio Envoy<br/>Sidecar]
        Pods -->|Injects| Dapr_Sidecar[Dapr Sidecar<br/>Optional]

        Pods -->|Connects| RDS
        Pods -->|Connects| S3
        Pods -->|Publishes| SNS
    end

    subgraph "Phase 6: Health Checks and Validation"
        Pods -->|Startup Probe| Startup[Pod startup<br/>Max 10 min]
        Startup -->|Readiness Probe| Readiness[Service traffic<br/>Load balancer]
        Readiness -->|Liveness Probe| Liveness[Continuous health<br/>Auto-restart]

        Liveness -->|Ready| VS[VirtualService<br/>Routes traffic]
        VS -->|Exposes| Gateway[Istio Gateway<br/>External access]
        Gateway -->|HTTPS| Users[End Users]
    end

    subgraph "Phase 7: Continuous Sync"
        ArgoCD -.->|Monitors| HelmRepo
        ArgoCD -.->|Auto-sync| K8s_Resources
        ESO_Controller -.->|Refresh 1h| Vault_DB
        K8s_Secrets -.->|Triggers restart| Pods
    end

    %% Styling
    classDef terraform fill:#7b42bc,stroke:#4a148c,color:#fff,stroke-width:2px
    classDef argocd fill:#f4511e,stroke:#bf360c,color:#fff,stroke-width:2px
    classDef vault fill:#ffd600,stroke:#f57f17,stroke-width:2px
    classDef k8s fill:#326ce5,stroke:#01579b,color:#fff,stroke-width:2px
    classDef istio fill:#466bb0,stroke:#1565c0,color:#fff,stroke-width:2px
    classDef aws fill:#ff9900,stroke:#e65100,stroke-width:2px

    class TF_Plan,TF_Apply terraform
    class ArgoCD,App,Helm argocd
    class Vault_Setup,Vault_K8s,Vault_DB,Vault_Policies,Vault_Roles,ESO_Controller vault
    class K8s_Resources,Deployments,Services,ConfigMaps,ExternalSecrets,Pods,K8s_Secrets k8s
    class VirtualServices,VS,Gateway,Istio_Sidecar istio
    class EKS,RDS,S3,IAM,SNS aws
```

## Deployment Phases

### Phase 1: Infrastructure Provisioning (Terraform)

**Prerequisites:**
- AWS credentials configured
- S3 backend for Terraform state
- DynamoDB table for state locking

**Execution:**
```bash
# Initialize Terraform backend
terraform init -backend-config=backend.hcl

# Validate configuration
terraform validate

# Plan infrastructure changes
terraform plan -out=tfplan

# Review plan output
cat tfplan

# Apply changes (requires manual approval)
terraform apply tfplan
```

**Outputs:**
- EKS cluster endpoint
- RDS endpoint
- S3 bucket names
- IAM role ARNs (for IRSA)
- VPC configuration

**Time:** ~20-25 minutes

### Phase 2: Secret Management Setup (Terraform + Vault)

Terraform automatically configures Vault:

**Vault Kubernetes Auth Backend:**
```hcl
resource "vault_auth_backend" "kubernetes" {
  type = "kubernetes"
  path = "kubernetes"
}
```

**Vault Database Secrets Engine:**
```hcl
resource "vault_database_secret_backend_connection" "postgres" {
  backend       = vault_mount.database.path
  name          = "judge-postgres"
  allowed_roles = ["judge-api", "archivista", "kratos"]

  postgresql {
    connection_url = "postgresql://{{username}}:{{password}}@${var.rds_endpoint}:5432/${var.db_name}"
  }
}
```

**Time:** ~2-3 minutes

### Phase 3: ArgoCD Application Deployment

**ArgoCD Application Manifest:**
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
        - values.yaml
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
    retry:
      limit: 5
      backoff:
        duration: 5s
        factor: 2
        maxDuration: 3m
```

**Sync Waves (Ordered Deployment):**
```yaml
# Wave -1: Secrets and ConfigMaps
argocd.argoproj.io/sync-wave: "-1"

# Wave 0: Core services (judge-api - initializes DB schema)
argocd.argoproj.io/sync-wave: "0"

# Wave 1: Dependent services (archivista, kratos)
argocd.argoproj.io/sync-wave: "1"

# Wave 2: Frontend and gateway
argocd.argoproj.io/sync-wave: "2"
```

**Time:** ~15-20 minutes (full deployment)

### Phase 4: Secret Synchronization (ESO)

**ExternalSecret Lifecycle:**
1. ESO controller detects ExternalSecret resource
2. Authenticates to Vault using ServiceAccount JWT
3. Reads secret from Vault path
4. Creates/updates Kubernetes Secret
5. Refreshes secret every 1 hour (configurable)

**Refresh Interval Configuration:**
```yaml
apiVersion: external-secrets.io/v1beta1
kind: ExternalSecret
metadata:
  name: judge-api-database
spec:
  refreshInterval: 1h  # Sync every hour
```

**Time:** ~30 seconds per secret

### Phase 5: Pod Startup

**Startup Sequence:**
1. **Sidecar Injection**: Istio Envoy + Dapr (if enabled)
2. **Init Containers**: Database migrations (judge-api only)
3. **Secret Mounting**: Kubernetes Secrets as environment variables
4. **Application Start**: Main container starts
5. **Startup Probe**: Waits up to 10 minutes for readiness
6. **Readiness Probe**: Pod accepts traffic when ready
7. **Liveness Probe**: Continuous health monitoring

**Example Startup Probe:**
```yaml
startupProbe:
  httpGet:
    path: /admin/health/ready
    port: 8080
  initialDelaySeconds: 10
  periodSeconds: 10
  failureThreshold: 60  # 10 minutes max
```

**Time:** ~2-5 minutes per deployment

### Phase 6: Health Checks and Validation

**Validation Checklist:**
- [ ] All pods in `Running` state
- [ ] All pods pass readiness probes
- [ ] Kubernetes Secrets created by ESO
- [ ] Database connections successful
- [ ] S3 bucket access verified
- [ ] SNS/SQS messaging working
- [ ] Istio VirtualServices configured
- [ ] External DNS records created
- [ ] HTTPS endpoints accessible

**Automated Validation Script:**
```bash
# Run validation suite
./scripts/validation/validate-deployment.sh

# Check specific components
./scripts/validation/check-prerequisites.sh
./scripts/validation/validate-infrastructure.sh
./scripts/validation/validate-external-secrets.sh
./scripts/validation/wait-for-healthy.sh
./scripts/validation/e2e-test.sh
```

**Time:** ~5-10 minutes

### Phase 7: Continuous Sync (GitOps)

**ArgoCD Auto-Sync:**
- **Frequency**: Every 3 minutes (default)
- **Prune**: Remove resources deleted from Git
- **Self-Heal**: Revert manual changes
- **Retry**: Automatic retry on failure (5 attempts)

**ESO Secret Refresh:**
- **Frequency**: Every 1 hour (configurable)
- **On-Demand**: Trigger via annotation change
- **Rotation**: Vault credential rotation (24h TTL)
- **Pod Restart**: Automatic on secret change (via deployment annotation)

## Rollback Procedures

### Terraform Rollback
```bash
# Revert infrastructure changes
git revert <commit-hash>
terraform apply

# Or restore from Terraform state backup
terraform state pull > current.tfstate
aws s3 cp s3://bucket/terraform.tfstate.backup ./
terraform state push terraform.tfstate.backup
```

### ArgoCD Rollback
```bash
# Rollback to previous revision
argocd app rollback judge-platform <revision>

# Or via UI
# Applications → judge-platform → History → Rollback
```

### Manual Rollback
```bash
# Rollback Kubernetes deployment
kubectl rollout undo deployment/judge-api -n judge

# Rollback specific revision
kubectl rollout undo deployment/judge-api --to-revision=2 -n judge
```

## Disaster Recovery

**RDS Automated Backups:**
- Retention: 7 days
- Point-in-time recovery: 5-minute granularity
- Cross-region replication: Optional

**S3 Versioning:**
- Enabled for all buckets
- Lifecycle policy: 30-day retention
- Cross-region replication: Optional

**Terraform State Backup:**
- S3 versioning enabled
- Daily snapshots to separate bucket
- Encryption at rest (AWS KMS)

## Performance Optimization

**Parallel Deployment:**
- Use ArgoCD sync waves for ordered deployment
- Independent services deploy in parallel
- Database migrations run serially (wave 0)

**Resource Requests:**
```yaml
resources:
  requests:
    memory: "256Mi"
    cpu: "100m"
  limits:
    memory: "512Mi"
    cpu: "500m"
```

**Horizontal Pod Autoscaling:**
```yaml
autoscaling:
  enabled: true
  minReplicas: 2
  maxReplicas: 10
  targetCPUUtilizationPercentage: 70
```

## Monitoring and Observability

**Deployment Metrics:**
- ArgoCD sync status and duration
- ESO secret sync errors
- Pod startup time
- Readiness probe failures
- Database migration duration

**Alerting:**
- ArgoCD sync failures
- Pod crash loops
- ESO authentication failures
- Vault credential expiration
- Database connection errors

**Logging:**
- ArgoCD application logs
- ESO controller logs
- Kubernetes events
- Application startup logs
