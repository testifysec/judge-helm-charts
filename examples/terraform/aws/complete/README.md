# Complete Terraform Example for Judge Platform on AWS

This example demonstrates a production-ready deployment of the Judge platform on AWS EKS using Terraform. It includes:

- **IAM Roles (IRSA)**: Service account roles for judge-api, archivista, and worker pods
- **External Secrets Operator**: Kubernetes operator for syncing secrets from Vault
- **Vault Configuration**: Kubernetes auth backend, database secrets engine, and policies
- **RDS PostgreSQL**: Managed database with multi-AZ deployment
- **S3 Buckets**: Object storage for artifacts and attestations
- **SNS/SQS**: Event bus for asynchronous communication

## Prerequisites

- AWS CLI configured with appropriate credentials
- Terraform >= 1.5.0
- An existing EKS cluster
- HashiCorp Vault deployed and accessible
- kubectl configured to access the EKS cluster

## Architecture

```
┌─────────────────────────────────────────────────────────────┐
│ EKS Cluster                                                 │
│                                                             │
│  ┌──────────────┐                                          │
│  │ judge-api    │──IRSA──> IAM Role                       │
│  │ pod          │              └──> S3 Policy              │
│  │              │              └──> SQS Policy             │
│  └──────────────┘                                          │
│         │                                                   │
│         │ ServiceAccount JWT                               │
│         ↓                                                   │
│  ┌──────────────┐                                          │
│  │ ESO          │                                          │
│  │ Controller   │                                          │
│  └──────────────┘                                          │
│         │                                                   │
│         │ Kubernetes Auth                                  │
│         ↓                                                   │
│  ┌──────────────┐                                          │
│  │ Vault        │──> Database Secrets Engine               │
│  │              │         └──> RDS PostgreSQL              │
│  └──────────────┘                                          │
│         │                                                   │
│         │ Dynamic Credentials                              │
│         ↓                                                   │
│  ┌──────────────┐                                          │
│  │ Kubernetes   │                                          │
│  │ Secrets      │                                          │
│  └──────────────┘                                          │
└─────────────────────────────────────────────────────────────┘
```

## Module Structure

```
complete/
├── README.md              # This file
├── main.tf                # Main Terraform configuration
├── variables.tf           # Input variables
├── outputs.tf             # Output values
├── terraform.tfvars.example  # Example variable values
├── backend.hcl.example    # S3 backend configuration
└── modules/
    ├── iam-irsa/          # IAM roles for service accounts
    ├── vault-config/      # Vault Kubernetes auth and policies
    └── external-secrets/  # ESO deployment and RBAC
```

## Quick Start

### 1. Configure Backend

```bash
# Copy backend configuration template
cp backend.hcl.example backend.hcl

# Edit with your S3 bucket and DynamoDB table
vim backend.hcl
```

**backend.hcl:**
```hcl
bucket         = "your-terraform-state-bucket"
key            = "judge/terraform.tfstate"
region         = "us-east-1"
dynamodb_table = "terraform-state-lock"
encrypt        = true
```

### 2. Configure Variables

```bash
# Copy variables template
cp terraform.tfvars.example terraform.tfvars

# Edit with your environment values
vim terraform.tfvars
```

**terraform.tfvars:**
```hcl
# AWS Configuration
aws_region     = "us-east-1"
cluster_name   = "my-eks-cluster"
environment    = "production"

# EKS Configuration
oidc_provider_arn = "arn:aws:iam::YOUR_ACCOUNT_ID:oidc-provider/oidc.eks.us-east-1.amazonaws.com/id/XXXXX"
namespace         = "judge"

# S3 Buckets
judge_bucket_name      = "my-env-judge-artifacts"
archivista_bucket_name = "my-env-archivista-attestations"

# RDS Configuration
rds_endpoint      = "my-db.us-east-1.rds.amazonaws.com"
rds_port          = 5432
rds_database_name = "judge"
rds_username      = "postgres"
rds_password      = "changeme"  # Use environment variable in production

# Vault Configuration
vault_address         = "https://vault.example.com"
vault_namespace       = ""  # For Vault Enterprise
vault_k8s_host        = "https://kubernetes.default.svc"
vault_k8s_ca_cert     = ""  # Will be fetched from K8s if empty

# SNS/SQS Configuration
sns_topic_name = "my-env-judge-archivista-attestations"
sqs_queue_name = "my-env-judge-archivista-attestations"

# Tags
tags = {
  Environment = "production"
  ManagedBy   = "terraform"
  Application = "judge"
}
```

### 3. Initialize and Apply

```bash
# Initialize Terraform with backend
terraform init -backend-config=backend.hcl

# Validate configuration
terraform validate

# Plan infrastructure changes
terraform plan -out=tfplan

# Review plan output
terraform show tfplan

# Apply changes
terraform apply tfplan
```

### 4. Verify Deployment

```bash
# Check IAM roles created
aws iam list-roles --query 'Roles[?contains(RoleName, `judge-api`)].RoleName'

# Verify ESO deployment
kubectl get pods -n external-secrets

# Check ExternalSecrets sync
kubectl get externalsecrets -n judge
kubectl describe externalsecret judge-api-database -n judge

# Verify Kubernetes Secrets created
kubectl get secrets -n judge | grep judge-judge

# Test Vault authentication
kubectl exec -it deploy/judge-api -n judge -- /bin/sh
# Inside pod:
# cat /var/run/secrets/kubernetes.io/serviceaccount/token
# export VAULT_ADDR=https://vault.example.com
# vault login -method=kubernetes role=judge-api jwt=$(cat /var/run/secrets/kubernetes.io/serviceaccount/token)
# vault kv get database/creds/judge-api
```

## IAM Roles (IRSA Pattern)

This example creates IAM roles for three Judge platform services using the IRSA (IAM Roles for Service Accounts) pattern:

### judge-api Role

**Permissions:**
- S3: Full access to judge artifacts bucket
- SQS: Receive and delete messages from attestation queue
- SNS: Subscribe to attestation topic

**ServiceAccount Binding:**
```yaml
apiVersion: v1
kind: ServiceAccount
metadata:
  name: judge-api
  namespace: judge
  annotations:
    eks.amazonaws.com/role-arn: arn:aws:iam::YOUR_ACCOUNT_ID:role/my-eks-cluster-judge-api
```

### archivista Role

**Permissions:**
- S3: Full access to archivista attestations bucket
- SNS: Publish to attestation topic

**ServiceAccount Binding:**
```yaml
apiVersion: v1
kind: ServiceAccount
metadata:
  name: archivista
  namespace: judge
  annotations:
    eks.amazonaws.com/role-arn: arn:aws:iam::YOUR_ACCOUNT_ID:role/my-eks-cluster-archivista
```

### worker Role

**Permissions:**
- S3: Read/write access to both judge and archivista buckets

**ServiceAccount Binding:**
```yaml
apiVersion: v1
kind: ServiceAccount
metadata:
  name: worker
  namespace: judge
  annotations:
    eks.amazonaws.com/role-arn: arn:aws:iam::YOUR_ACCOUNT_ID:role/my-eks-cluster-worker
```

## Vault Configuration

### Kubernetes Auth Backend

Enables Vault authentication using Kubernetes ServiceAccount tokens:

```hcl
# Enable Kubernetes auth method
vault auth enable kubernetes

# Configure Kubernetes auth backend
vault write auth/kubernetes/config \
    kubernetes_host="https://kubernetes.default.svc" \
    kubernetes_ca_cert=@/var/run/secrets/kubernetes.io/serviceaccount/ca.crt \
    token_reviewer_jwt=@/var/run/secrets/kubernetes.io/serviceaccount/token
```

### Database Secrets Engine

Generates dynamic database credentials with automatic rotation:

```hcl
# Enable database secrets engine
vault secrets enable database

# Configure PostgreSQL connection
vault write database/config/judge-postgres \
    plugin_name=postgresql-database-plugin \
    allowed_roles="judge-api,archivista,kratos" \
    connection_url="postgresql://{{username}}:{{password}}@my-db.us-east-1.rds.amazonaws.com:5432/judge?sslmode=require" \
    username="postgres" \
    password="changeme"

# Create database role for judge-api
vault write database/roles/judge-api \
    db_name=judge-postgres \
    creation_statements="CREATE USER \"{{name}}\" WITH PASSWORD '{{password}}' VALID UNTIL '{{expiration}}'; \
                        GRANT SELECT, INSERT, UPDATE, DELETE ON ALL TABLES IN SCHEMA public TO \"{{name}}\";" \
    default_ttl="24h" \
    max_ttl="72h"
```

### Vault Policies

Define fine-grained access control:

```hcl
# judge-api policy
path "database/creds/judge-api" {
  capabilities = ["read"]
}

path "secret/data/production/kubernetes/app/testifysec-judge" {
  capabilities = ["read"]
}

# archivista policy
path "database/creds/archivista" {
  capabilities = ["read"]
}
```

### Kubernetes Auth Roles

Bind ServiceAccounts to Vault policies:

```hcl
# judge-api role binding
vault write auth/kubernetes/role/judge-api \
    bound_service_account_names=judge-api \
    bound_service_account_namespaces=judge \
    policies=judge-api \
    ttl=24h
```

## External Secrets Operator

### SecretStore

Configures how ESO connects to Vault:

```yaml
apiVersion: external-secrets.io/v1beta1
kind: SecretStore
metadata:
  name: vault
  namespace: judge
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

### ExternalSecret

Defines which secrets to sync from Vault:

```yaml
apiVersion: external-secrets.io/v1beta1
kind: ExternalSecret
metadata:
  name: judge-api-database
  namespace: judge
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

## Outputs

This Terraform configuration outputs the following values:

- **IAM Role ARNs**: For annotating ServiceAccounts in Helm values
- **S3 Bucket Names**: For configuring application storage
- **RDS Endpoint**: For database connection configuration
- **Vault Configuration**: Auth backend paths and role names
- **ESO Status**: External Secrets Operator deployment status

## Security Best Practices

1. **Use Vault for Secrets**: Never hardcode credentials in Terraform or Helm values
2. **Enable S3 Encryption**: All buckets should have encryption at rest enabled
3. **RDS Encryption**: Enable encryption for RDS instances
4. **Least Privilege IAM**: Grant only necessary permissions to each service
5. **VPC Endpoints**: Use VPC endpoints for S3, SQS, SNS to avoid internet traffic
6. **Dynamic Credentials**: Use Vault database secrets engine for automatic rotation
7. **Secret Rotation**: Configure ESO refresh interval (default: 1h)
8. **Audit Logging**: Enable Vault audit logs and CloudTrail

## Troubleshooting

### IAM Role Not Assumed by Pod

**Symptoms:**
```
AccessDenied: User: arn:aws:sts::ACCOUNT:assumed-role/nodes/i-xxx is not authorized to perform: s3:GetObject
```

**Solution:**
1. Verify ServiceAccount annotation:
   ```bash
   kubectl get sa judge-api -n judge -o yaml
   # Should have: eks.amazonaws.com/role-arn annotation
   ```

2. Check OIDC provider exists:
   ```bash
   aws iam list-open-id-connect-providers
   ```

3. Verify trust relationship in IAM role:
   ```bash
   aws iam get-role --role-name my-eks-cluster-judge-api
   # Check AssumeRolePolicyDocument for correct OIDC provider ARN
   ```

### ESO Cannot Authenticate to Vault

**Symptoms:**
```
ExternalSecret.status.conditions: Authentication failed
```

**Solution:**
1. Check Vault Kubernetes auth configuration:
   ```bash
   vault read auth/kubernetes/config
   ```

2. Verify ServiceAccount token is mounted:
   ```bash
   kubectl exec -it deploy/judge-api -n judge -- cat /var/run/secrets/kubernetes.io/serviceaccount/token
   ```

3. Test Vault authentication manually:
   ```bash
   vault write auth/kubernetes/login role=judge-api jwt=$(cat /var/run/secrets/kubernetes.io/serviceaccount/token)
   ```

### Dynamic Database Credentials Not Generated

**Symptoms:**
```
Error: failed to fetch secret from Vault: database/creds/judge-api
```

**Solution:**
1. Verify database connection in Vault:
   ```bash
   vault read database/config/judge-postgres
   ```

2. Test database role:
   ```bash
   vault read database/creds/judge-api
   # Should return username and password
   ```

3. Check RDS security group allows Vault access

## Cleanup

To destroy all resources:

```bash
# Destroy Terraform-managed resources
terraform destroy

# Delete Kubernetes resources
kubectl delete namespace judge

# Delete S3 buckets (if not managed by Terraform)
aws s3 rb s3://my-env-judge-artifacts --force
aws s3 rb s3://my-env-archivista-attestations --force
```

## References

- [Terraform AWS IAM Module](https://registry.terraform.io/modules/terraform-aws-modules/iam/aws/latest)
- [External Secrets Operator](https://external-secrets.io/)
- [Vault Kubernetes Auth](https://www.vaultproject.io/docs/auth/kubernetes)
- [Vault Database Secrets Engine](https://www.vaultproject.io/docs/secrets/databases/postgresql)
- [EKS IAM Roles for Service Accounts](https://docs.aws.amazon.com/eks/latest/userguide/iam-roles-for-service-accounts.html)
