# Preview Router - Build and Deploy Instructions

## Build and Push Docker Image

Since Docker Desktop is having issues, here are the manual steps to build and push the preview-router image to ECR:

### 1. Restart Docker Desktop
Open Docker Desktop app and ensure it's running properly.

### 2. Authenticate to ECR
```bash
export AWS_PROFILE=conda-demo
aws ecr get-login-password --region us-east-1 | docker login --username AWS --password-stdin 178674732984.dkr.ecr.us-east-1.amazonaws.com
```

### 3. Create ECR Repository (if needed)
```bash
aws ecr describe-repositories --repository-names preview-router --region us-east-1 || \
aws ecr create-repository --repository-name preview-router --region us-east-1
```

### 4. Build the Docker Image
```bash
cd /Users/nkennedy/proj/cust/conda/repos/judge-helm-charts/charts/preview-router
docker build -t preview-router:v0.1.0 .
```

### 5. Tag for ECR
```bash
docker tag preview-router:v0.1.0 178674732984.dkr.ecr.us-east-1.amazonaws.com/preview-router:v0.1.0
docker tag preview-router:v0.1.0 178674732984.dkr.ecr.us-east-1.amazonaws.com/preview-router:latest
```

### 6. Push to ECR
```bash
docker push 178674732984.dkr.ecr.us-east-1.amazonaws.com/preview-router:v0.1.0
docker push 178674732984.dkr.ecr.us-east-1.amazonaws.com/preview-router:latest
```

## Deploy via ArgoCD

### 1. Apply Terraform Changes for DNS
```bash
cd /Users/nkennedy/proj/cust/conda/repos/cust-anaconda-terraform-aws
terraform apply -target=module.route53
```

This will create the `*.preview.testifysec-demo.xyz` CNAME record pointing to the Istio ingress.

### 2. Update Judge Platform Values
Enable preview-router in your values file:

```yaml
preview-router:
  enabled: true
  image:
    repository: 178674732984.dkr.ecr.us-east-1.amazonaws.com/preview-router
    tag: v0.1.0
```

### 3. Commit and Push Changes
```bash
# In judge-helm-charts repo
git add charts/preview-router
git commit -m "feat: add preview-router for preview environment authentication"
git push

# In cust-anaconda-terraform-aws repo
git add modules/route53/main.tf
git commit -m "feat: add DNS record for preview subdomain"
git push
```

### 4. Sync ArgoCD
```bash
kubectl config use-context arn:aws:eks:us-east-1:831646886084:cluster/demo-judge
argocd app sync judge-platform --grpc-web
argocd app wait judge-platform --health --sync
```

## Verify Deployment

### 1. Check Pod Status
```bash
kubectl get pods -n judge | grep preview-router
```

### 2. Check Service
```bash
kubectl get svc -n judge | grep preview-router
```

### 3. Test Health Endpoint
```bash
kubectl port-forward -n judge svc/judge-platform-preview-router 8080:80
curl http://localhost:8080/health
```

### 4. Verify DNS (after TTL expires)
```bash
dig test123.preview.testifysec-demo.xyz
# Should resolve to Istio ingress load balancer
```

### 5. Test Auth Flow
```bash
# Visit in browser:
https://test123.preview.testifysec-demo.xyz/
# Should redirect to login if not authenticated

# After login:
https://login.testifysec-demo.xyz/post-auth?next=https://test123.preview.testifysec-demo.xyz/
# Should redirect to preview environment with auth cookie
```

## Troubleshooting

### DNS Not Resolving
- Wait 5 minutes for TTL to expire
- Check Route53 in AWS Console for the record
- Verify Istio Gateway has preview hosts configured

### Certificate Issues
- Check cert-manager logs: `kubectl logs -n cert-manager deploy/cert-manager`
- Verify certificate: `kubectl get certificate preview-wildcard-tls -n istio-system`
- Check DNS-01 challenge: `kubectl get challenges -n istio-system`

### Preview Router Not Working
- Check logs: `kubectl logs -n judge deploy/judge-platform-preview-router`
- Verify VirtualService: `kubectl get vs -n judge login-vs -o yaml`
- Test internal service: `kubectl exec -n judge deploy/judge-platform-judge-api -- curl http://judge-platform-preview-router:8080/health`

### Authentication Issues
- Verify Kratos allowed_return_urls includes `/post-auth`
- Check cookie domain in browser dev tools
- Ensure preview service exists and is healthy