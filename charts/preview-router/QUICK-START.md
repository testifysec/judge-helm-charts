# Preview Router - Quick Start

## Absolute Minimum to Get Working (Critical Path)

### 1. Build & Push Image (5 min)
```bash
cd charts/preview-router/app
docker build -t 178674732984.dkr.ecr.us-east-1.amazonaws.com/preview-router:v0.1.0 .
aws ecr get-login-password --region us-east-1 | docker login --username AWS --password-stdin 178674732984.dkr.ecr.us-east-1.amazonaws.com
docker push 178674732984.dkr.ecr.us-east-1.amazonaws.com/preview-router:v0.1.0
```

### 2. Add DNS Record (5 min)
In Route53:
- Name: `*.preview`
- Type: CNAME
- Value: Get from `kubectl -n istio-system get svc istio-ingressgateway -o jsonpath='{.status.loadBalancer.ingress[0].hostname}'`

### 3. Enable in Values (2 min)
Edit `cust-anaconda-values/values/base-values.yaml`:
```yaml
preview-router:
  enabled: true
```

### 4. Commit & Deploy (10 min)
```bash
# In judge-helm-charts
git add -A && git commit -m "feat: add preview-router" && git push

# In cust-anaconda-values
git add -A && git commit -m "values: enable preview-router" && git push

# Deploy
argocd app sync judge-platform --grpc-web
```

### 5. Quick Test
```bash
# Should see 2 pods running
kubectl get pods -n judge | grep preview-router

# Should see preview VS
kubectl get vs -n judge | grep preview

# Test locally
kubectl port-forward svc/judge-platform-preview-router -n judge 8080:8080
curl -H "Host: test.preview.testifysec-demo.xyz" http://localhost:8080/health
```

## That's It!

With these 5 steps, the core routing infrastructure is live.

**Still needed for full auth flow:**
- TLS certificate for `*.preview.testifysec-demo.xyz`
- Preview apps checking Kratos session
- CI/CD creating preview deployments

But the router will work and route traffic immediately.