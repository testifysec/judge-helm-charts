# Judge Platform AWS Infrastructure - Complete Example
#
# This example demonstrates production-ready infrastructure for Judge platform
# including IAM roles (IRSA), RDS, S3, SNS/SQS, and External Secrets Operator.

terraform {
  required_version = ">= 1.5.0"

  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.0"
    }
    kubernetes = {
      source  = "hashicorp/kubernetes"
      version = "~> 2.23"
    }
    helm = {
      source  = "hashicorp/helm"
      version = "~> 2.11"
    }
    vault = {
      source  = "hashicorp/vault"
      version = "~> 3.20"
    }
  }

  # S3 backend for state storage
  # Configure using backend.hcl file
  backend "s3" {}
}

provider "aws" {
  region = var.aws_region

  default_tags {
    tags = var.tags
  }
}

provider "kubernetes" {
  host                   = data.aws_eks_cluster.cluster.endpoint
  cluster_ca_certificate = base64decode(data.aws_eks_cluster.cluster.certificate_authority[0].data)
  token                  = data.aws_eks_cluster_auth.cluster.token
}

provider "helm" {
  kubernetes {
    host                   = data.aws_eks_cluster.cluster.endpoint
    cluster_ca_certificate = base64decode(data.aws_eks_cluster.cluster.certificate_authority[0].data)
    token                  = data.aws_eks_cluster_auth.cluster.token
  }
}

provider "vault" {
  address   = var.vault_address
  namespace = var.vault_namespace
}

# Data sources for existing EKS cluster
data "aws_eks_cluster" "cluster" {
  name = var.cluster_name
}

data "aws_eks_cluster_auth" "cluster" {
  name = var.cluster_name
}

# =============================================================================
# IAM Roles for Service Accounts (IRSA)
# =============================================================================

# Judge API Service Account Role
module "judge_api_irsa" {
  source  = "terraform-aws-modules/iam/aws//modules/iam-role-for-service-accounts-eks"
  version = "~> 5.0"

  role_name = "${var.cluster_name}-judge-api"

  oidc_providers = {
    main = {
      provider_arn               = var.oidc_provider_arn
      namespace_service_accounts = ["${var.namespace}:judge-api"]
    }
  }

  role_policy_arns = {
    policy = aws_iam_policy.judge_api.arn
  }

  tags = var.tags
}

resource "aws_iam_policy" "judge_api" {
  name        = "${var.cluster_name}-judge-api-policy"
  description = "Policy for Judge API service account"

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = concat([
      {
        Effect = "Allow"
        Action = [
          "s3:GetObject",
          "s3:PutObject",
          "s3:DeleteObject",
          "s3:ListBucket"
        ]
        Resource = [
          aws_s3_bucket.judge.arn,
          "${aws_s3_bucket.judge.arn}/*"
        ]
      }
    ], var.enable_messaging ? [
      {
        Effect = "Allow"
        Action = [
          "sqs:GetQueueAttributes",
          "sqs:GetQueueUrl",
          "sqs:ReceiveMessage",
          "sqs:DeleteMessage"
        ]
        Resource = [aws_sqs_queue.attestations[0].arn]
      },
      {
        Effect = "Allow"
        Action = [
          "sns:GetTopicAttributes",
          "sns:Subscribe",
          "sns:ListSubscriptionsByTopic"
        ]
        Resource = [aws_sns_topic.attestations[0].arn]
      }
    ] : [])
  })

  tags = var.tags
}

# Archivista Service Account Role
module "archivista_irsa" {
  source  = "terraform-aws-modules/iam/aws//modules/iam-role-for-service-accounts-eks"
  version = "~> 5.0"

  role_name = "${var.cluster_name}-archivista"

  oidc_providers = {
    main = {
      provider_arn               = var.oidc_provider_arn
      namespace_service_accounts = ["${var.namespace}:archivista"]
    }
  }

  role_policy_arns = {
    policy = aws_iam_policy.archivista.arn
  }

  tags = var.tags
}

resource "aws_iam_policy" "archivista" {
  name        = "${var.cluster_name}-archivista-policy"
  description = "Policy for Archivista service account"

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = concat([
      {
        Effect = "Allow"
        Action = [
          "s3:GetObject",
          "s3:PutObject",
          "s3:DeleteObject",
          "s3:ListBucket"
        ]
        Resource = [
          aws_s3_bucket.archivista.arn,
          "${aws_s3_bucket.archivista.arn}/*"
        ]
      }
    ], var.enable_messaging ? [
      {
        Effect = "Allow"
        Action = [
          "sns:Publish",
          "sns:GetTopicAttributes"
        ]
        Resource = [aws_sns_topic.attestations[0].arn]
      }
    ] : [])
  })

  tags = var.tags
}

# =============================================================================
# S3 Buckets
# =============================================================================

resource "aws_s3_bucket" "judge" {
  bucket = var.judge_bucket_name

  tags = merge(var.tags, {
    Name = "${var.environment}-judge-artifacts"
  })
}

resource "aws_s3_bucket_versioning" "judge" {
  bucket = aws_s3_bucket.judge.id

  versioning_configuration {
    status = "Enabled"
  }
}

resource "aws_s3_bucket_server_side_encryption_configuration" "judge" {
  bucket = aws_s3_bucket.judge.id

  rule {
    apply_server_side_encryption_by_default {
      sse_algorithm = "AES256"
    }
  }
}

resource "aws_s3_bucket_public_access_block" "judge" {
  bucket = aws_s3_bucket.judge.id

  block_public_acls       = true
  block_public_policy     = true
  ignore_public_acls      = true
  restrict_public_buckets = true
}

resource "aws_s3_bucket" "archivista" {
  bucket = var.archivista_bucket_name

  tags = merge(var.tags, {
    Name = "${var.environment}-archivista-attestations"
  })
}

resource "aws_s3_bucket_versioning" "archivista" {
  bucket = aws_s3_bucket.archivista.id

  versioning_configuration {
    status = "Enabled"
  }
}

resource "aws_s3_bucket_server_side_encryption_configuration" "archivista" {
  bucket = aws_s3_bucket.archivista.id

  rule {
    apply_server_side_encryption_by_default {
      sse_algorithm = "AES256"
    }
  }
}

resource "aws_s3_bucket_public_access_block" "archivista" {
  bucket = aws_s3_bucket.archivista.id

  block_public_acls       = true
  block_public_policy     = true
  ignore_public_acls      = true
  restrict_public_buckets = true
}

# =============================================================================
# SNS/SQS for Event-Driven Architecture (Optional)
# =============================================================================

resource "aws_sns_topic" "attestations" {
  count = var.enable_messaging ? 1 : 0

  name = var.sns_topic_name

  tags = merge(var.tags, {
    Name = "${var.environment}-attestations-topic"
  })
}

resource "aws_sqs_queue" "attestations" {
  count = var.enable_messaging ? 1 : 0

  name                       = var.sqs_queue_name
  visibility_timeout_seconds = 300
  message_retention_seconds  = 1209600 # 14 days

  tags = merge(var.tags, {
    Name = "${var.environment}-attestations-queue"
  })
}

resource "aws_sns_topic_subscription" "attestations" {
  count = var.enable_messaging ? 1 : 0

  topic_arn = aws_sns_topic.attestations[0].arn
  protocol  = "sqs"
  endpoint  = aws_sqs_queue.attestations[0].arn
}

resource "aws_sqs_queue_policy" "attestations" {
  count = var.enable_messaging ? 1 : 0

  queue_url = aws_sqs_queue.attestations[0].id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Principal = {
          Service = "sns.amazonaws.com"
        }
        Action   = "sqs:SendMessage"
        Resource = aws_sqs_queue.attestations[0].arn
        Condition = {
          ArnEquals = {
            "aws:SourceArn" = aws_sns_topic.attestations[0].arn
          }
        }
      }
    ]
  })
}

# =============================================================================
# External Secrets Operator
# =============================================================================

resource "helm_release" "external_secrets" {
  name       = "external-secrets"
  repository = "https://charts.external-secrets.io"
  chart      = "external-secrets"
  version    = var.eso_version
  namespace  = "external-secrets-system"

  create_namespace = true

  set {
    name  = "installCRDs"
    value = "true"
  }

  # Terraform-managed RBAC to avoid ArgoCD sync conflicts
  set {
    name  = "rbac.create"
    value = "false"
  }
}

# External Secrets Operator RBAC (Terraform-managed)
resource "kubernetes_cluster_role" "external_secrets_controller" {
  metadata {
    name = "external-secrets-controller"
  }

  rule {
    api_groups = [""]
    resources  = ["secrets"]
    verbs      = ["get", "list", "watch", "create", "update", "patch", "delete"]
  }

  rule {
    api_groups = [""]
    resources  = ["serviceaccounts", "namespaces"]
    verbs      = ["get", "list", "watch"]
  }

  rule {
    api_groups = ["external-secrets.io"]
    resources  = ["secretstores", "clustersecretstores", "externalsecrets", "clusterexternalsecrets"]
    verbs      = ["get", "list", "watch", "update", "patch"]
  }

  rule {
    api_groups = ["external-secrets.io"]
    resources  = ["secretstores/status", "clustersecretstores/status", "externalsecrets/status", "clusterexternalsecrets/status"]
    verbs      = ["update", "patch"]
  }

  rule {
    api_groups = ["apiextensions.k8s.io"]
    resources  = ["customresourcedefinitions"]
    verbs      = ["get", "list", "watch"]
  }
}

resource "kubernetes_cluster_role_binding" "external_secrets_controller" {
  metadata {
    name = "external-secrets-controller"
  }

  role_ref {
    api_group = "rbac.authorization.k8s.io"
    kind      = "ClusterRole"
    name      = kubernetes_cluster_role.external_secrets_controller.metadata[0].name
  }

  subject {
    kind      = "ServiceAccount"
    name      = "external-secrets"
    namespace = "external-secrets-system"
  }
}

# =============================================================================
# Vault Configuration
# =============================================================================

# Enable Kubernetes auth backend
resource "vault_auth_backend" "kubernetes" {
  type = "kubernetes"
  path = "kubernetes"
}

resource "vault_kubernetes_auth_backend_config" "kubernetes" {
  backend            = vault_auth_backend.kubernetes.path
  kubernetes_host    = var.vault_k8s_host
  kubernetes_ca_cert = var.vault_k8s_ca_cert != "" ? var.vault_k8s_ca_cert : data.kubernetes_secret.sa_token.data["ca.crt"]
  token_reviewer_jwt = var.vault_token_reviewer_jwt != "" ? var.vault_token_reviewer_jwt : data.kubernetes_secret.sa_token.data["token"]
}

# Service account for Vault token reviewer
data "kubernetes_secret" "sa_token" {
  metadata {
    name      = kubernetes_service_account.vault_auth.default_secret_name
    namespace = kubernetes_service_account.vault_auth.metadata[0].namespace
  }
}

resource "kubernetes_service_account" "vault_auth" {
  metadata {
    name      = "vault-auth"
    namespace = "kube-system"
  }
}

resource "kubernetes_cluster_role_binding" "vault_auth_delegator" {
  metadata {
    name = "vault-auth-delegator"
  }

  role_ref {
    api_group = "rbac.authorization.k8s.io"
    kind      = "ClusterRole"
    name      = "system:auth-delegator"
  }

  subject {
    kind      = "ServiceAccount"
    name      = kubernetes_service_account.vault_auth.metadata[0].name
    namespace = kubernetes_service_account.vault_auth.metadata[0].namespace
  }
}

# Vault Policies
resource "vault_policy" "judge_api" {
  name = "judge-api"

  policy = <<EOT
# Database credentials
path "database/creds/judge-api" {
  capabilities = ["read"]
}

# Application secrets
path "secret/data/${var.environment}/kubernetes/app/testifysec-judge" {
  capabilities = ["read"]
}
EOT
}

resource "vault_policy" "archivista" {
  name = "archivista"

  policy = <<EOT
# Database credentials
path "database/creds/archivista" {
  capabilities = ["read"]
}
EOT
}

resource "vault_policy" "kratos" {
  name = "kratos"

  policy = <<EOT
# Database credentials
path "database/creds/kratos" {
  capabilities = ["read"]
}

# Application secrets (OIDC, SMTP)
path "secret/data/${var.environment}/kubernetes/app/testifysec-judge" {
  capabilities = ["read"]
}
EOT
}

# Vault Kubernetes Auth Roles
resource "vault_kubernetes_auth_backend_role" "judge_api" {
  backend                          = vault_auth_backend.kubernetes.path
  role_name                        = "judge-api"
  bound_service_account_names      = ["judge-api"]
  bound_service_account_namespaces = [var.namespace]
  token_policies                   = [vault_policy.judge_api.name]
  token_ttl                        = 86400 # 24 hours
}

resource "vault_kubernetes_auth_backend_role" "archivista" {
  backend                          = vault_auth_backend.kubernetes.path
  role_name                        = "archivista"
  bound_service_account_names      = ["archivista"]
  bound_service_account_namespaces = [var.namespace]
  token_policies                   = [vault_policy.archivista.name]
  token_ttl                        = 86400
}

resource "vault_kubernetes_auth_backend_role" "kratos" {
  backend                          = vault_auth_backend.kubernetes.path
  role_name                        = "kratos"
  bound_service_account_names      = ["kratos"]
  bound_service_account_namespaces = [var.namespace]
  token_policies                   = [vault_policy.kratos.name]
  token_ttl                        = 86400
}

# Vault Database Secrets Engine
# Note: This example shows the configuration pattern
# In production, consider using a separate Terraform module for database configuration

# Outputs
output "judge_api_role_arn" {
  description = "ARN of the judge-api IAM role for IRSA"
  value       = module.judge_api_irsa.iam_role_arn
}

output "archivista_role_arn" {
  description = "ARN of the archivista IAM role for IRSA"
  value       = module.archivista_irsa.iam_role_arn
}

output "judge_bucket_name" {
  description = "Name of the S3 bucket for Judge artifacts"
  value       = aws_s3_bucket.judge.id
}

output "archivista_bucket_name" {
  description = "Name of the S3 bucket for Archivista attestations"
  value       = aws_s3_bucket.archivista.id
}

output "vault_auth_path" {
  description = "Vault Kubernetes auth backend path"
  value       = vault_auth_backend.kubernetes.path
}
