# Judge Helm Charts Project

## Deployment Strategy

- **Upstream Repository**: `testifysec/judge-helm-charts` (public)
  - PR branch: `feature/eso-vault-integration`
  - Contains ESO/Vault integration, Kratos fixes, architecture diagrams

- **Values Repository**: `testifysec/judge-platform-values` (private)
  - Contains customer-specific AWS configuration
  - Separate files for base config and ingress config
  - No actual secrets stored (uses External Secrets Operator)

- **ArgoCD Multi-Source Deployment**:
  - Source 1: Helm chart from `testifysec/judge-helm-charts` (feature/eso-vault-integration branch)
  - Source 2: Values from `testifysec/judge-platform-values` (private repo)
  - Namespace: `judge`
  - Automated sync with prune and self-heal enabled

## AWS Environment

- **EKS Cluster**: `demo-judge` in AWS account `831646886084`
  - Region: `us-east-1`
  - AWS Profile: `conda-demo`
  - Kubectl context: `arn:aws:eks:us-east-1:831646886084:cluster/demo-judge`

- **Container Registry**: Cross-account ECR access
  - ECR account: `178674732984`
  - Registry URL: `178674732984.dkr.ecr.us-east-1.amazonaws.com`
  - IRSA roles in cluster account (`831646886084`) have cross-account ECR pull permissions

## Important Notes

- You must deploy via ArgoCD sync, debug the root cause of any sync issues
- MinIO is disabled (using S3 for object storage)
- MySQL is disabled (using RDS PostgreSQL)
- Registry configuration uses object structure: `global.registry.url` and `global.registry.repository`
- External Secrets Operator manages all secrets from HashiCorp Vault
- IRSA (IAM Roles for Service Accounts) provides AWS permissions to pods
- Dapr pubsub enabled with SNS/SQS configuration

## Working Repositories

### 1. judge-helm-charts (Upstream PR - Active Development)
- **Path**: `/Users/nkennedy/proj/cust/conda/repos/judge-helm-charts`
- **Remote**: `upstream` → `git@github.com:testifysec/judge-helm-charts.git`
- **Branch**: `feature/eso-vault-integration`
- **PR**: https://github.com/testifysec/judge-helm-charts/pull/1
- **Purpose**: Upstream PR with ESO/Vault integration, SecretStore templates
- **ArgoCD Source**: This is the Helm chart source (Source 1)

### 2. judge-platform-values (Private Values - Active Deployment)
- **Path**: `/Users/nkennedy/proj/cust/conda/repos/cust-anaconda-values`
- **Remote**: `origin` → `git@github.com:testifysec/judge-platform-values.git`
- **Branch**: `main`
- **Purpose**: AWS-specific configuration values (accounts, regions, IAM roles)
- **Files**:
  - `values/base-values.yaml` - AWS infrastructure, image tags, Dapr config
  - `values/ingress-values.yaml` - Domain and networking
  - `argocd/judge-application.yaml` - ArgoCD Application manifest
- **ArgoCD Source**: This is the values source (Source 2)

### 3. cust-anaconda-helm-charts (Customer Fork - Reference)
- **Path**: `/Users/nkennedy/proj/cust/conda/repos/cust-anaconda-helm-charts`
- **Remote**: `origin` → `git@github.com:testifysec/cust-anaconda-helm-charts.git`
- **Branch**: `feature/eso-vault-integration`
- **Purpose**: Customer fork for reference (demo-values.yaml has working config)
- **Note**: Not actively deploying from this repo

### 4. cust-anaconda-terraform-aws (Infrastructure - Can Update)
- **Path**: `/Users/nkennedy/proj/cust/conda/repos/cust-anaconda-terraform-aws`
- **Purpose**: Terraform modules for AWS infrastructure
- **Key Modules**:
  - `modules/vault-config/` - Vault Kubernetes auth roles (judge-api, archivista, kratos)
  - `modules/eks-addons/` - EKS cluster and add-ons
  - `modules/rds/` - RDS PostgreSQL database
  - `modules/s3/` - S3 buckets
  - `modules/sns-sqs/` - Messaging infrastructure
- **Vault Roles**: Creates Kubernetes auth roles for judge-api, archivista, kratos (NOT judge-eso)

## Deployment Flow

**ArgoCD syncs with PR branch HEAD**: ArgoCD should sync with the latest commits in https://github.com/testifysec/judge-helm-charts/pull/1 (feature/eso-vault-integration branch)