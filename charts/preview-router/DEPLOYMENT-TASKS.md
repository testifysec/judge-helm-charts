# Preview Authentication - Remaining Deployment Tasks

## Priority 1: Infrastructure Setup (Day 1)
_Must be done first - everything else depends on these_

### 1.1 Build and Push Router Image
- [ ] Navigate to: `charts/preview-router/app/`
- [ ] Build image: `docker build -t 178674732984.dkr.ecr.us-east-1.amazonaws.com/preview-router:v0.1.0 .`
- [ ] Push to ECR: `docker push 178674732984.dkr.ecr.us-east-1.amazonaws.com/preview-router:v0.1.0`
- [ ] Verify image exists in ECR console
**Blocker for**: Router deployment

### 1.2 Configure DNS
- [ ] Login to Route53 (or DNS provider)
- [ ] Add CNAME record:
  - Name: `*.preview.testifysec-demo.xyz`
  - Value: `<istio-ingress-loadbalancer-dns>`
  - TTL: 300
- [ ] Test DNS resolution: `nslookup test123.preview.testifysec-demo.xyz`
**Blocker for**: All preview access

### 1.3 Create TLS Certificate
- [ ] Create certificate manifest: `charts/judge/templates/preview-certificate.yaml`
```yaml
{{- if and .Values.istio.enabled (index .Values "preview-router" "enabled") }}
apiVersion: cert-manager.io/v1
kind: Certificate
metadata:
  name: preview-wildcard-tls
  namespace: istio-system
spec:
  secretName: preview-wildcard-tls
  issuerRef:
    name: letsencrypt-prod
    kind: ClusterIssuer
  dnsNames:
    - "*.preview.testifysec-demo.xyz"
{{- end }}
```
- [ ] Apply certificate
- [ ] Wait for cert-manager to issue (check with: `kubectl get certificate -n istio-system`)
**Blocker for**: HTTPS access

### 1.4 Update Istio Gateway
- [ ] Edit: `charts/judge/templates/istio-gateway.yaml`
- [ ] Add preview server block:
```yaml
{{- if (index .Values "preview-router" "enabled") }}
- port:
    number: 443
    name: https-preview
    protocol: HTTPS
  tls:
    mode: SIMPLE
    credentialName: preview-wildcard-tls
  hosts:
    - "*.preview.{{ .Values.istio.domain }}"
{{- end }}
```
**Blocker for**: HTTPS routing

---

## Priority 2: Deploy Router (Day 1)
_Once infrastructure is ready_

### 2.1 Enable in Values
- [ ] Edit: `cust-anaconda-values/values/base-values.yaml`
```yaml
preview-router:
  enabled: true
  preview:
    domainSuffix: "preview.testifysec-demo.xyz"
    fallbackUrl: "https://judge.testifysec-demo.xyz/"
```

### 2.2 Commit Changes
- [ ] In `judge-helm-charts`:
  ```bash
  git add -A
  git commit -m "feat: add preview-router for preview environment authentication"
  git push origin feature/eso-vault-integration
  ```
- [ ] In `cust-anaconda-values`:
  ```bash
  git add values/base-values.yaml
  git commit -m "values: enable preview-router"
  git push
  ```

### 2.3 Deploy via ArgoCD
- [ ] Sync application: `argocd app sync judge-platform --grpc-web`
- [ ] Verify pods: `kubectl get pods -n judge | grep preview-router`
- [ ] Check VirtualServices: `kubectl get vs -n judge | grep preview`
- [ ] Check certificate: `kubectl get certificate -n istio-system | grep preview`

---

## Priority 3: Validate Core Functionality (Day 1)
_Test the basic routing works_

### 3.1 Test Router Health
- [ ] Port forward: `kubectl port-forward svc/judge-platform-preview-router -n judge 8080:8080`
- [ ] Test health: `curl http://localhost:8080/health`
- [ ] Test routing with Host header: `curl -H "Host: test123.preview.testifysec-demo.xyz" http://localhost:8080/`

### 3.2 Test Post-Auth Endpoint
- [ ] Valid redirect: `curl -i "http://localhost:8080/post-auth?next=https://abc1234.preview.testifysec-demo.xyz/"`
- [ ] Invalid redirect: `curl -i "http://localhost:8080/post-auth?next=https://evil.com/"`
- [ ] Should see 302 redirects in both cases

---

## Priority 4: Preview App Integration (Day 2)
_Make preview apps auth-aware_

### 4.1 Update judge-web for Auth Check
- [ ] Add auth check to preview app (judge-web):
```javascript
// pages/_app.tsx or similar
useEffect(() => {
  checkAuth();
}, []);

async function checkAuth() {
  const resp = await fetch('https://kratos.testifysec-demo.xyz/sessions/whoami', {
    credentials: 'include'
  });

  if (!resp.ok) {
    const currentUrl = window.location.href;
    const postAuth = `https://login.testifysec-demo.xyz/post-auth?next=${encodeURIComponent(currentUrl)}`;
    const loginUrl = `https://kratos.testifysec-demo.xyz/self-service/login/browser?return_to=${encodeURIComponent(postAuth)}`;
    window.location.href = loginUrl;
  }
}
```

### 4.2 Configure CORS
- [ ] Verify Kratos CORS includes preview domains
- [ ] Check `allowed_origins` in Kratos config includes wildcard or specific preview domains

---

## Priority 5: CI/CD Setup (Day 2)
_Automate preview deployments_

### 5.1 Create Preview Deployment Workflow
- [ ] Add `.github/workflows/deploy-preview.yaml` to judge-web repo
- [ ] Use template from: `charts/preview-router/examples/github-action.yaml`
- [ ] Configure AWS credentials and kubectl access
- [ ] Test on a PR

### 5.2 Create Cleanup Workflow
- [ ] Add cleanup job for PR close
- [ ] Test cleanup removes deployment and service

### 5.3 PR Comment Integration
- [ ] Add GitHub Action step to comment preview URL
- [ ] Include both preview URL and auth URL in comment
- [ ] Test comment appears on PR

---

## Priority 6: End-to-End Testing (Day 2)
_Validate complete flow_

### 6.1 Deploy Test Preview
- [ ] Create test PR in judge-web
- [ ] Wait for CI to deploy preview
- [ ] Get preview URL from PR comment

### 6.2 Test Authentication Flow
- [ ] Visit preview URL (should redirect to login)
- [ ] Complete GitHub OAuth
- [ ] Verify redirect to `/post-auth`
- [ ] Verify bounce to preview environment
- [ ] Confirm session cookie works

### 6.3 Test Edge Cases
- [ ] Missing preview (should get 503)
- [ ] Invalid SHA format (should redirect to fallback)
- [ ] Direct `/post-auth` access without `next` param

---

## Priority 7: Documentation (Day 3)
_Ensure team can use it_

### 7.1 Update Team Documentation
- [ ] Add preview auth flow to platform docs
- [ ] Document DNS/TLS requirements
- [ ] Add troubleshooting guide

### 7.2 Create Runbook
- [ ] Common issues and fixes
- [ ] How to debug auth failures
- [ ] How to manually deploy previews

### 7.3 Demo to Team
- [ ] Schedule team demo
- [ ] Show auth flow
- [ ] Answer questions

---

## Success Criteria Checklist

- [ ] Router pod running in cluster
- [ ] DNS resolves for `*.preview.testifysec-demo.xyz`
- [ ] TLS certificate valid for preview subdomain
- [ ] `/post-auth` endpoint accessible on `login.testifysec-demo.xyz`
- [ ] Preview VirtualService routing works
- [ ] Kratos accepts `/post-auth` in return URLs
- [ ] Test preview environment accessible after auth
- [ ] CI/CD creates previews automatically
- [ ] Team understands how to use system

---

## Rollback Plan

If issues arise:
1. Disable preview-router: Set `enabled: false` in values
2. Remove preview VirtualService manually if needed
3. DNS and TLS can remain (no impact)
4. Document issue for debugging

---

## Notes

- **Current blocker**: None - ready to start with Task 1.1
- **Dependencies**: Must complete Priority 1 before anything else works
- **Time estimate**: 2-3 days for full implementation
- **Risk**: TLS certificate issuance might take time with DNS-01 challenge