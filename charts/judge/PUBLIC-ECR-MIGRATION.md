# Public ECR Migration Plan

## Overview
This document outlines the plan to migrate all public container images to AWS Public ECR (`public.ecr.aws`) to improve reliability, reduce rate limiting, and optimize for AWS deployments.

## Current Status

### ✅ Already Using public.ecr.aws
- **postgres** - `public.ecr.aws/docker/library/postgres` (postgresql chart)
- **localstack** - `public.ecr.aws/localstack/localstack` (localstack chart)
- **busybox** - `public.ecr.aws/docker/library/busybox:latest` (kratos deployment init container)

### 🔄 Needs Migration

#### High Priority (Production Runtime)
These images run in production pods and should be migrated first:

| Current Image | Public ECR Equivalent | Chart | File |
|--------------|----------------------|-------|------|
| `ghcr.io/testifysec/kratos` | `public.ecr.aws/testifysec/kratos` | kratos | `charts/kratos/values.yaml:15` |
| `ghcr.io/dexidp/dex` | `public.ecr.aws/dexidp/dex` | dex | `charts/dex/values.yaml:14` |
| `amazon/aws-cli` | `public.ecr.aws/aws-cli/aws-cli` | judge-preflight | `charts/judge-preflight/values.yaml:12` |
| `busybox` | `public.ecr.aws/docker/library/busybox` | localstack | `charts/localstack/templates/deployment.yaml:25` |
| `busybox` | `public.ecr.aws/docker/library/busybox` | kratos-selfservice-ui-node | `charts/kratos-selfservice-ui-node/values.yaml:192` |
| `busybox` | `public.ecr.aws/docker/library/busybox` | kratos | `charts/kratos/values.yaml:839` |
| `ollama/ollama` | `public.ecr.aws/ollama/ollama` | ollama | `charts/ollama/values.yaml:14` |

#### Medium Priority (Utility/Init Containers)
These images are used for initialization or utilities:

| Current Image | Public ECR Equivalent | Chart | File |
|--------------|----------------------|-------|------|
| `oryd/k8s-toolbox:0.0.5` | `public.ecr.aws/oryd/k8s-toolbox:0.0.5` | kratos | `charts/kratos/values.yaml:727` |
| `bitnami/kubectl:latest` | `public.ecr.aws/bitnami/kubectl:latest` | kratos | `charts/kratos/templates/job-validate-github-secret.yaml:27` |

#### Low Priority (Test/Development)
These images are only used in test pods or optional features:

| Current Image | Public ECR Equivalent | Chart | File |
|--------------|----------------------|-------|------|
| `curlimages/curl:7.86.0` | `public.ecr.aws/curlimages/curl:7.86.0` | judge-ai-proxy | `charts/judge-ai-proxy/templates/tests/test-connection.yaml:13` |
| `busybox` | `public.ecr.aws/docker/library/busybox` | ollama | `charts/ollama/templates/tests/test-connection.yaml:12` |

### ⚠️ Special Cases

#### Sigstore Images (gcr.io/ghcr.io)
These images from the Sigstore project may not have Public ECR mirrors:

| Current Image | Status | Chart | File |
|--------------|--------|-------|------|
| `gcr.io/projectsigstore/fulcio@sha256:...` | ❓ Check availability | fulcio | `charts/fulcio/Chart.yaml:24` |
| `ghcr.io/sigstore/scaffolding/createcerts@sha256:...` | ❓ Check availability | fulcio | `charts/fulcio/Chart.yaml:26` |
| `ghcr.io/sigstore/timestamp-server@sha256:...` | ❓ Check availability | tsa | `charts/tsa/Chart.yaml:25` |

**Recommendation**: Check if Sigstore maintains Public ECR mirrors. If not, consider:
1. Keeping these on their original registries (they're pinned by SHA256)
2. Mirroring to our private ECR (`178674732984.dkr.ecr.us-east-1.amazonaws.com`)
3. Contributing to Sigstore to request Public ECR mirrors

## Benefits of Migration

### 1. Rate Limiting Avoidance
- **Docker Hub**: 100 pulls/6hrs (anonymous), 200 pulls/6hrs (authenticated)
- **GitHub Container Registry**: Rate limits per user/org
- **Public ECR**: No rate limiting for pulls

### 2. Performance
- Lower latency when running on AWS (same region)
- Better throughput for image pulls
- Reduced startup time for pods

### 3. Reliability
- AWS SLA guarantees
- Geographic redundancy
- Consistent with our existing AWS infrastructure

## Implementation Plan

### Phase 1: High Priority Runtime Images (Week 1)
1. **Verify availability** on Public ECR for each image
2. **Update values files** with new repository paths
3. **Test** in dev environment
4. **Deploy** to staging
5. **Validate** in production

### Phase 2: Utility/Init Containers (Week 2)
1. Migrate oryd/k8s-toolbox and bitnami/kubectl
2. Standardize all busybox references to use public.ecr.aws

### Phase 3: Test Images (Week 3)
1. Update test pod images
2. Verify Helm test suites pass

### Phase 4: Sigstore Decision (Week 4)
1. Research Sigstore Public ECR availability
2. Make decision on mirroring strategy
3. Implement chosen approach

## Migration Checklist

### Pre-Migration
- [ ] Verify all images exist on Public ECR
- [ ] Document current image versions
- [ ] Create rollback plan
- [ ] Update CLAUDE.md with migration notes

### Per-Image Migration
- [ ] Update values.yaml or template with new registry
- [ ] Test image pull locally: `docker pull public.ecr.aws/...`
- [ ] Update helm-unittest tests if needed
- [ ] Run `helm lint charts/[chartname]`
- [ ] Run `helm unittest charts/judge`
- [ ] Bump chart version
- [ ] Git commit with descriptive message

### Post-Migration
- [ ] Deploy to dev environment
- [ ] Verify all pods start successfully
- [ ] Monitor image pull times
- [ ] Deploy to staging
- [ ] Deploy to production
- [ ] Document lessons learned

## Verification Commands

### Check if image exists on Public ECR
```bash
# For Docker Hub official images
docker pull public.ecr.aws/docker/library/[image]:[tag]

# For other vendors
docker pull public.ecr.aws/[vendor]/[image]:[tag]
```

### Verify image pull in cluster
```bash
kubectl run test-pull --rm -it --restart=Never \
  --image=public.ecr.aws/[vendor]/[image]:[tag] \
  -- /bin/sh
```

## Rollback Plan

If issues arise after migration:

1. **Immediate**: Revert values files to previous registry
2. **Short-term**: Deploy previous Helm chart version
3. **Long-term**: Use ArgoCD rollback functionality

## Resources

- [AWS Public ECR Documentation](https://docs.aws.amazon.com/AmazonECR/latest/public/public-registries.html)
- [Public ECR Gallery](https://gallery.ecr.aws/)
- [Docker Hub Rate Limits](https://docs.docker.com/docker-hub/download-rate-limit/)

## Success Metrics

- ✅ 0 image pull failures due to rate limiting
- ✅ <30s pod startup time improvement
- ✅ 100% image availability
- ✅ All 72 tests passing

## Next Steps

1. **Immediate**: Verify high-priority images exist on Public ECR
2. **This Sprint**: Migrate runtime images (Phase 1)
3. **Next Sprint**: Complete utility and test migrations (Phases 2-3)
4. **Future**: Evaluate Sigstore mirroring strategy (Phase 4)
