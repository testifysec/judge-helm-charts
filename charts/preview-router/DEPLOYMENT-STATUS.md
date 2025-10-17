# Preview Router - Deployment Status

## ✅ Completed Tasks

### 1. Implementation
- Created minimal Go HTTP router for preview environment authentication
- Implemented post-auth redirect handler for Kratos authentication flow
- Added reverse proxy functionality for preview services
- Created Helm subchart with deployment and service templates

### 2. Integration
- Added preview-router as dependency in judge chart (v1.7.24)
- Updated Kratos allowed_return_urls to include `/post-auth`
- Modified login VirtualService to route `/post-auth` to preview-router
- Added preview VirtualService for wildcard domain routing
- Updated Gateway configuration for preview subdomain

### 3. TLS & Certificates
- Created Certificate manifest for `*.preview.testifysec-demo.xyz`
- Configured cert-manager with DNS-01 challenge for wildcard cert

### 4. DNS Configuration
- Added Route53 record for `*.preview.testifysec-demo.xyz` in Terraform module
- Points to Istio ingress load balancer

### 5. Bug Fixes
- Fixed Helm chart packaging (removed binary, added .helmignore)
- Fixed template errors for nil preview-router values
- Chart versions bumped: judge (1.7.24), preview-router (0.1.0)

## 🔄 Remaining Tasks

### 1. Build and Push Docker Image
```bash
# After Docker Desktop is working:
cd /Users/nkennedy/proj/cust/conda/repos/judge-helm-charts/charts/preview-router

# Authenticate to ECR
export AWS_PROFILE=conda-demo
aws ecr get-login-password --region us-east-1 | docker login --username AWS --password-stdin 178674732984.dkr.ecr.us-east-1.amazonaws.com

# Create ECR repository if needed
aws ecr describe-repositories --repository-names preview-router --region us-east-1 || \
aws ecr create-repository --repository-name preview-router --region us-east-1

# Build and tag
docker build -t preview-router:v0.1.0 .
docker tag preview-router:v0.1.0 178674732984.dkr.ecr.us-east-1.amazonaws.com/preview-router:v0.1.0
docker tag preview-router:v0.1.0 178674732984.dkr.ecr.us-east-1.amazonaws.com/preview-router:latest

# Push to ECR
docker push 178674732984.dkr.ecr.us-east-1.amazonaws.com/preview-router:v0.1.0
docker push 178674732984.dkr.ecr.us-east-1.amazonaws.com/preview-router:latest
```

### 2. Apply Terraform DNS Changes
```bash
cd /Users/nkennedy/proj/cust/conda/repos/cust-anaconda-terraform-aws

# Review changes
terraform plan -target=module.route53

# Apply DNS record for preview subdomain
terraform apply -target=module.route53 -auto-approve
```

### 3. Enable Preview Router in Values
Add to your environment values file (e.g., `staging-values.yaml`):

```yaml
preview-router:
  enabled: true
  image:
    repository: 178674732984.dkr.ecr.us-east-1.amazonaws.com/preview-router
    tag: v0.1.0
  resources:
    requests:
      memory: "64Mi"
      cpu: "50m"
    limits:
      memory: "128Mi"
      cpu: "100m"
```

### 4. Deploy via ArgoCD
```bash
# The staging environment will auto-sync once values are updated
# For manual sync:
argocd app sync judge-staging --grpc-web
argocd app wait judge-staging --health --sync
```

### 5. Verify Deployment
```bash
# Check pod status
kubectl get pods -n judge-staging | grep preview-router

# Check service
kubectl get svc -n judge-staging | grep preview-router

# Test health endpoint
kubectl port-forward -n judge-staging svc/judge-staging-preview-router 8080:8080
curl http://localhost:8080/health

# Check DNS (wait 5 minutes for TTL)
dig test123.preview.testifysec-demo.xyz
```

### 6. Test Authentication Flow
1. Visit: `https://test123.preview.testifysec-demo.xyz/`
2. Should redirect to login page
3. After login, should redirect via: `https://login.testifysec-demo.xyz/post-auth?next=https://test123.preview.testifysec-demo.xyz/`
4. Cookie should be set for `.testifysec-demo.xyz`
5. Should be able to access any `*.preview.testifysec-demo.xyz` subdomain

## Architecture Summary

```
User → *.preview.testifysec-demo.xyz
     ↓
Istio Gateway (port 443, TLS)
     ↓
Preview VirtualService
     ↓
preview-router:8080
     ↓
Routes:
  - /health → 200 OK
  - /post-auth → validate & redirect
  - /* → proxy to preview-{sha} service

Auth Flow:
1. User visits preview URL
2. Preview service redirects to login
3. Kratos authenticates user
4. Redirects to /post-auth with next URL
5. preview-router validates & redirects
6. Cookie valid for all subdomains
```

## Troubleshooting

### Docker Build Issues
- Ensure Docker Desktop is running
- Check Docker daemon: `docker info`
- Restart Docker Desktop if needed

### DNS Not Resolving
- Wait 5 minutes for TTL expiration
- Check Route53 console for record
- Verify Istio Gateway has hosts configured

### Certificate Issues
- Check cert-manager logs: `kubectl logs -n cert-manager deploy/cert-manager`
- Verify challenge: `kubectl get challenges -n istio-system`
- Check certificate: `kubectl get certificate preview-wildcard-tls -n istio-system`

### Preview Router Errors
- Check logs: `kubectl logs -n judge-staging deploy/judge-staging-preview-router`
- Verify environment variables are set
- Check service connectivity

### Authentication Issues
- Verify Kratos allowed_return_urls includes `/post-auth`
- Check cookie domain in browser dev tools
- Ensure preview service exists and is healthy

## Files Changed

### Modified
- `charts/judge/Chart.yaml` - Added preview-router dependency, bumped to v1.7.24
- `charts/judge/Chart.lock` - Updated with preview-router
- `charts/judge/templates/_helpers.tpl` - Added /post-auth to allowed_return_urls
- `charts/judge/templates/istio-gateway.yaml` - Added preview subdomain server
- `charts/judge/templates/istio-virtualservices.yaml` - Added post-auth route and preview VS
- `modules/route53/main.tf` - Added preview wildcard DNS record

### Created
- `charts/preview-router/` - Complete subchart implementation
- `charts/judge/templates/preview-certificate.yaml` - TLS certificate for preview subdomain

## Next Steps for CI/CD

After manual deployment succeeds, set up automated preview deployments:

1. **GitHub Action for Preview Deployments**
   - Trigger on PR open/update
   - Build and tag preview image
   - Deploy to preview-{sha} namespace
   - Comment PR with preview URL

2. **Cleanup on PR Close**
   - Delete preview namespace
   - Remove preview image from ECR

3. **Integration with Judge Platform**
   - Update gateway to recognize preview headers
   - Add preview environment detection to web UI

See `charts/preview-router/examples/github-action.yaml` for sample workflow.