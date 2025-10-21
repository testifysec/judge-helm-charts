# Preview Authentication Deployment Checklist

## 🚀 Phase 1: Get It Running (30 min)

### Infrastructure
- [ ] Build Docker image: `docker build -t preview-router:v0.1.0 .`
- [ ] Push to ECR: `docker push 178674732984.dkr.ecr.us-east-1.amazonaws.com/preview-router:v0.1.0`
- [ ] Add DNS: `*.preview.testifysec-demo.xyz` → Istio LB
- [ ] Enable in values: `preview-router.enabled: true`
- [ ] Commit both repos
- [ ] ArgoCD sync

### Validation
- [ ] Pods running: `kubectl get pods -n judge | grep preview-router`
- [ ] VS exists: `kubectl get vs -n judge | grep preview`
- [ ] Health check: `curl localhost:8080/health` (after port-forward)

---

## 🔒 Phase 2: TLS & Security (1 hour)

### TLS Setup
- [ ] Create Certificate resource for `*.preview.testifysec-demo.xyz`
- [ ] Wait for cert-manager to issue
- [ ] Update Gateway with preview server block
- [ ] Test HTTPS: `curl https://test.preview.testifysec-demo.xyz/health`

### Auth Flow
- [ ] Verify `/post-auth` route in login VS
- [ ] Check Kratos allowed_return_urls includes `/post-auth`
- [ ] Test post-auth redirect locally

---

## 🔄 Phase 3: CI/CD Integration (2 hours)

### Preview Deployment
- [ ] Add GitHub Action workflow to judge-web
- [ ] Configure AWS credentials
- [ ] Test preview deployment on PR
- [ ] Verify preview Service/Deployment created

### Preview Cleanup
- [ ] Add cleanup workflow for closed PRs
- [ ] Test cleanup removes resources

### PR Comments
- [ ] Add comment with preview URL
- [ ] Include auth URL in comment
- [ ] Test comment appears

---

## ✅ Phase 4: End-to-End Test (30 min)

### Full Flow Test
- [ ] Create test PR
- [ ] Visit preview URL from PR comment
- [ ] Complete GitHub OAuth
- [ ] Land in preview environment
- [ ] Verify session cookie works

### Edge Cases
- [ ] Test missing preview (503 response)
- [ ] Test invalid host (redirect to fallback)
- [ ] Test direct /post-auth access

---

## 📝 Phase 5: Documentation (1 hour)

- [ ] Update platform docs
- [ ] Create troubleshooting guide
- [ ] Demo to team
- [ ] Get feedback

---

## Quick Commands Reference

```bash
# Check router status
kubectl get pods -n judge | grep preview-router

# View router logs
kubectl logs -n judge -l app.kubernetes.io/name=preview-router

# Test routing locally
kubectl port-forward svc/judge-platform-preview-router -n judge 8080:8080
curl -H "Host: abc123.preview.testifysec-demo.xyz" http://localhost:8080/

# Check DNS
nslookup test.preview.testifysec-demo.xyz

# Check TLS cert
kubectl get certificate -n istio-system preview-wildcard-tls

# Force ArgoCD sync
argocd app sync judge-platform --force --grpc-web
```

## Troubleshooting

**Router not starting?**
- Check image exists in ECR
- Check resource limits
- View pod logs

**DNS not resolving?**
- Check Route53 record
- Wait for propagation (up to 5 min)
- Try `dig` instead of `nslookup`

**Auth not working?**
- Check Kratos allowed_return_urls
- Verify cookie domain (no leading dot needed)
- Check browser dev tools for cookies

**Preview not accessible?**
- Check preview Service exists
- Check preview Deployment is running
- Check router logs for errors

## Success Indicators

✅ `kubectl get pods -n judge | grep preview-router` shows 2/2 Running
✅ `curl https://test.preview.testifysec-demo.xyz/` returns response
✅ GitHub PR shows preview URL comment
✅ Auth flow completes without errors
✅ Team can access preview environments