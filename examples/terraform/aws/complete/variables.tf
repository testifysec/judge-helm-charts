# AWS Configuration
variable "aws_region" {
  description = "AWS region for resources"
  type        = string
  default     = "us-east-1"
}

variable "environment" {
  description = "Environment name (dev, staging, production)"
  type        = string
}

variable "tags" {
  description = "Tags to apply to all resources"
  type        = map(string)
  default     = {}
}

# EKS Configuration
variable "cluster_name" {
  description = "Name of the EKS cluster"
  type        = string
}

variable "oidc_provider_arn" {
  description = "ARN of the EKS OIDC provider"
  type        = string
}

variable "namespace" {
  description = "Kubernetes namespace for Judge platform"
  type        = string
  default     = "judge"
}

# S3 Configuration
variable "judge_bucket_name" {
  description = "Name of the S3 bucket for Judge artifacts"
  type        = string
}

variable "archivista_bucket_name" {
  description = "Name of the S3 bucket for Archivista attestations"
  type        = string
}

# Messaging Configuration
variable "enable_messaging" {
  description = "Enable SNS/SQS for event-driven architecture"
  type        = bool
  default     = true
}

variable "sns_topic_name" {
  description = "Name of the SNS topic for attestation events"
  type        = string
  default     = ""
}

variable "sqs_queue_name" {
  description = "Name of the SQS queue for attestation events"
  type        = string
  default     = ""
}

# Vault Configuration
variable "vault_address" {
  description = "Vault server address"
  type        = string
}

variable "vault_namespace" {
  description = "Vault namespace (for Vault Enterprise)"
  type        = string
  default     = ""
}

variable "vault_k8s_host" {
  description = "Kubernetes API server URL for Vault auth"
  type        = string
  default     = "https://kubernetes.default.svc"
}

variable "vault_k8s_ca_cert" {
  description = "Kubernetes CA certificate for Vault auth (auto-detected if empty)"
  type        = string
  default     = ""
  sensitive   = true
}

variable "vault_token_reviewer_jwt" {
  description = "JWT token for Vault Kubernetes auth (auto-detected if empty)"
  type        = string
  default     = ""
  sensitive   = true
}

# External Secrets Operator
variable "eso_version" {
  description = "Version of External Secrets Operator Helm chart"
  type        = string
  default     = "0.11.0"
}
