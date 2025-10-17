# Judge Preflight Chart

Pre-flight validation checks for Judge platform deployment.

## Purpose

This chart validates all prerequisites before deploying the Judge platform, including:

- **Infrastructure Services**: External Secrets Operator, cert-manager, PostgreSQL
- **Cloud Resources**: AWS S3 buckets, SNS/SQS queues, RDS connectivity
- **Secrets**: Fulcio certificates, GitHub OAuth credentials
- **Vault Integration**: Connectivity and Kubernetes auth roles (production)
- **LocalStack**: Service readiness and bucket creation (dev/staging)

## Usage

### Production

```bash
helm install judge-preflight ./charts/judge-preflight \
  --namespace judge \
  --create-namespace \
  --values ./charts/judge-preflight/values-production.yaml
```

### Dev/Staging

```bash
# Dev
helm install judge-preflight ./charts/judge-preflight \
  --namespace judge-dev \
  --create-namespace \
  --values ./charts/judge-preflight/values-dev.yaml

# Staging
helm install judge-preflight ./charts/judge-preflight \
  --namespace judge-staging \
  --create-namespace \
  --values ./charts/judge-preflight/values-staging.yaml \
  --set secrets.githubOAuth.name=judge-staging-github-oauth
```

## Validation Checks

### All Environments

- ✅ cert-manager installed and ready
- ✅ PostgreSQL/RDS reachable
- ✅ Fulcio server secret exists with required keys

### Production Only

- ✅ External Secrets Operator installed (3+ pods running)
- ✅ Vault server reachable
- ✅ Vault Kubernetes auth roles configured (judge-api, archivista, kratos)
- ✅ AWS S3 buckets exist (demo-judge-judge, demo-judge-archivista)
- ✅ AWS SNS/SQS resources exist

### Dev/Staging Only

- ✅ PostgreSQL pod ready
- ✅ LocalStack service ready
- ✅ LocalStack buckets created (judge-artifacts, archivista, archivista-attestations)
- ✅ GitHub OAuth secret exists with clientId/clientSecret

## Integration with Judge Chart

Add as a dependency to the Judge chart:

```yaml
# charts/judge/Chart.yaml
dependencies:
  - name: judge-preflight
    version: 0.1.0
    repository: file://../judge-preflight
    condition: judge-preflight.enabled
```

This ensures preflight checks run automatically before Judge platform deployment.

## Customization

Override any values in your custom values file:

```yaml
# custom-values.yaml
externalSecrets:
  namespace: external-secrets  # Custom ESO namespace

database:
  host: my-rds-endpoint.amazonaws.com

aws:
  s3Buckets:
    - my-custom-bucket
```

## Troubleshooting

If preflight checks fail:

1. **Check the job logs**: `kubectl logs -n <namespace> job/<release>-preflight`
2. **Review error messages**: The job provides specific guidance for each failure
3. **Fix the issue**: Follow the instructions in the error message
4. **Re-run**: Delete the failed job and upgrade/install again

Example error output:

```
==========================================
ERROR: GitHub OAuth Secret Not Found
==========================================

The secret 'judge-dev-github-oauth' does not exist.

To create this secret, run:

  kubectl create secret generic judge-dev-github-oauth \
    --namespace judge-dev \
    --from-literal=clientId=<your-github-client-id> \
    --from-literal=clientSecret=<your-github-client-secret>

Obtain credentials from: https://github.com/settings/developers
==========================================
```

## Skipping Checks

Disable specific checks by setting values to `false`:

```yaml
vault:
  enabled: false  # Skip Vault checks

aws:
  enabled: false  # Skip AWS resource checks
```
