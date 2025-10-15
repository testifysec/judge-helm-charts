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

## Working Directories

- Helm charts: `/Users/nkennedy/proj/cust/conda/repos/cust-anaconda-helm-charts` (customer fork)
- Upstream PR: `/Users/nkennedy/proj/cust/conda/repos/judge-helm-charts` (feature/eso-vault-integration)
- Values repo: `/Users/nkennedy/proj/cust/conda/repos/cust-anaconda-values`
