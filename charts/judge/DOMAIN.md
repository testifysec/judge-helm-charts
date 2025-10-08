# Domain Configuration

## Overview

The Judge platform uses a **single domain** for all external services, configured via `global.domain` in `values.yaml`. This domain is used for:

- Istio VirtualService hostnames (*.testifysec-demo.xyz)
- OIDC redirect URIs (Kratos, Dex, Fulcio)
- Service discovery URLs
- TLS certificate Subject Alternative Names (SANs)

## Current Domain

The default domain is: **testifysec-demo.xyz**

## Configuration Location

**Single Source of Truth**: `values.yaml` line 5
```yaml
global:
  domain: testifysec-demo.xyz
```

## Validation

The chart includes runtime validation that ensures `istio.domain` matches `global.domain`. If they don't match, `helm template` or `helm install` will fail with:

```
ERROR: global.domain (X) MUST match istio.domain (Y). Update istio.domain in values.yaml to match global.domain.
```

## Hardcoded URLs Requiring Manual Updates

Due to Helm's lack of templating support in values.yaml, **22 locations** contain hardcoded domain references that must be manually updated when changing domains:

### Gateway & Login (2 locations)
- [ ] Line ~48: `gateway.login.url`

### Kratos Configuration (4 locations)
- [ ] Lines ~64-68: `kratos.kratos.config.selfservice.allowed_return_urls[]` (4 entries)

### Dex Configuration (4 locations)
- [ ] Line ~181: `dex.ingress.hosts[0].host`
- [ ] Line ~188: `dex.ingress.tls[0].hosts[0]`
- [ ] Line ~190: `dex.config.issuer`
- [ ] Line ~211: `dex.config.connectors[0].config.redirectURI`

### Fulcio Configuration (4 locations)
- [ ] Line ~229: `fulcio.server.ingress.http.hosts[0].host`
- [ ] Line ~233: `fulcio.server.ingress.tls[0].hosts[0]`
- [ ] Line ~242: `fulcio.server.ingress.grpc.hosts[0].host`
- [ ] Line ~247: `fulcio.server.ingress.grpc.tls[0].hosts[0]`
- [ ] Line ~264: `fulcio.config.contents.OIDCIssuers` (Dex issuer URL)

### TSA Configuration (2 locations)
- [ ] Line ~290: `tsa.server.ingress.http.hosts[0].host`
- [ ] Line ~294: `tsa.server.ingress.tls[0].hosts[0]`

### AI Proxy Configuration (2 locations)
- [ ] Line ~327: `judge-ai-proxy.ingress.hosts[0].host`
- [ ] Line ~334: `judge-ai-proxy.ingress.tls[0].hosts[0]`

### Istio (1 location - validated)
- [ ] Line ~18: `istio.domain` (MUST match global.domain)

## How to Change Domains

### Step 1: Update global.domain
```yaml
global:
  domain: your-new-domain.com  # Change this
```

### Step 2: Update istio.domain
```yaml
istio:
  domain: your-new-domain.com  # MUST match global.domain
```

### Step 3: Find and Replace Hardcoded URLs
```bash
cd charts/judge

# Verify current domain usage
grep -n "testifysec-demo.xyz" values.yaml

# Replace all occurrences (review carefully!)
sed -i '' 's/testifysec-demo\.xyz/your-new-domain.com/g' values.yaml
```

### Step 4: Run Tests
```bash
./tests/test-domain-consistency.sh
./tests/test-global-domain-propagation.sh
./tests/test-virtualservice-hosts.sh
```

### Step 5: Verify Helm Template
```bash
helm template test . --namespace test | grep "your-new-domain.com" | wc -l
# Should show multiple matches (VirtualServices, config references, etc.)

helm template test . --namespace test | grep "testifysec-demo.xyz" | wc -l
# Should show 0 matches
```

### Step 6: Update TLS Certificate
Ensure your wildcard TLS certificate covers the new domain:
```yaml
istio:
  tlsSecretName: wildcard-tls  # Must contain cert for *.your-new-domain.com
```

## Testing

Three automated tests verify domain consistency:

```bash
# Run all tests
cd charts/judge/tests
./test-domain-consistency.sh      # Verifies all values.yaml URLs use global.domain
./test-global-domain-propagation.sh # Verifies istio.domain == global.domain
./test-virtualservice-hosts.sh    # Verifies VirtualServices use correct domain
```

All tests must pass before deployment.

## Why Not Use Templating?

Helm's `values.yaml` does **not** support Go template syntax. You cannot use `{{ .Values.global.domain }}` inside values.yaml itself. This limitation forces us to:

1. Use `global.domain` as documentation/reference
2. Manually keep all 22 URLs in sync
3. Rely on runtime validation to catch mismatches
4. Use tests to verify consistency

## Troubleshooting

### Error: Domains don't match
```
ERROR: global.domain (X) MUST match istio.domain (Y)
```

**Solution**: Update `istio.domain` in values.yaml to match `global.domain`.

### Services unreachable after domain change
**Symptoms**: 404 errors, "Host not found"

**Checklist**:
- [ ] Updated DNS records for *.new-domain.com → LoadBalancer IP
- [ ] Updated TLS certificate to cover *.new-domain.com
- [ ] Verified all 22 URLs in values.yaml use new domain
- [ ] Ran `helm upgrade` to apply changes

### OIDC redirect failures
**Symptoms**: "redirect_uri_mismatch" errors from Dex/Kratos

**Solution**: Ensure `dex.config.issuer` and all `allowed_return_urls` use the new domain.

## References

- [Helm Values Files](https://helm.sh/docs/chart_template_guide/values_files/)
- [Istio VirtualService](https://istio.io/latest/docs/reference/config/networking/virtual-service/)
- [Kratos Configuration](https://www.ory.sh/docs/kratos/reference/configuration)
