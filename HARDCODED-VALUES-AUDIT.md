# Hardcoded Values Audit Report

## 🔴 CRITICAL - Must Fix

### 1. preview-router Chart
**File**: `charts/preview-router/values.yaml:10`
```yaml
repository: 178674732984.dkr.ecr.us-east-1.amazonaws.com/preview-router
```
**Issue**: Hardcoded internal ECR account ID
**Fix**: Should use `global.registry.url` pattern

**File**: `charts/preview-router/values.yaml:31-32`
```yaml
fallbackUrl: "https://judge.testifysec-demo.xyz/"
domainSuffix: "preview.testifysec-demo.xyz"
```
**Issue**: Hardcoded demo domain
**Fix**: Should use `global.domain` pattern

### 2. kratos-selfservice-ui-node Chart
**Files**: Multiple (60, 66, 176)
```yaml
- host: login.testifysec.localhost
kratosBrowserUrl: "http://kratos.testifysec.localhost"
```
**Issue**: Hardcoded localhost domain
**Fix**: Should be configurable from parent chart's domain setting

### 3. judge-web Chart
**Files**: Multiple (66, 77, 92)
```yaml
- host: "judge.testifysec.localhost"
```
**Issue**: Hardcoded localhost domain
**Fix**: Should use ingress.hosts pattern from parent

### 4. kratos Chart
**Files**: Multiple (121, 128, 207-271, 309)
```yaml
base_url: https://kratos.testifysec.localhost
ui_url: https://login.testifysec.localhost/*
domain: testifysec.localhost
```
**Issue**: Extensive hardcoded localhost domains
**Fix**: Should template from global.domain

### 5. judge Chart (Parent)
**Files**: Multiple (30, 238, 275, 295-299, 437, 458, 474, 476)
```yaml
domain: testifysec-demo.xyz
url: "https://login.testifysec-demo.xyz/login"
issuer: https://dex.testifysec-demo.xyz
```
**Issue**: Demo domain used as default
**Fix**: Should have empty/generic default or use localhost

### 6. archivista Chart
**File**: `charts/archivista/values.yaml:96`
```yaml
- host: archivista.testifysec.localhost
```
**Issue**: Hardcoded localhost domain
**Fix**: Should use parent domain setting

### 7. judge-api Chart
**File**: `charts/judge-api/values.yaml:136`
```yaml
- host: judge-api.testifysec.localhost
```
**Issue**: Hardcoded localhost domain
**Fix**: Should use parent domain setting

## 🟡 ACCEPTABLE - But Worth Noting

### 1. Upstream Registries (gcr.io, ghcr.io)
**Files**: fulcio, dex, tsa, dapr Chart.yaml dependencies
```yaml
image: gcr.io/projectsigstore/fulcio@sha256:...
image: ghcr.io/dexidp/dex:v2.39.0
registry: ghcr.io/dapr
```
**Status**: ✅ OK - These are legitimate upstream public registries

### 2. Template Placeholders
**Files**: kratos, archivista values.yaml
```yaml
registry: YOUR_ACCOUNT_ID.dkr.ecr.us-east-1.amazonaws.com
```
**Status**: ✅ OK - Clear placeholders for documentation

### 3. AWS Marketplace Account
**File**: `charts/judge/values.yaml:111` (comment)
```yaml
# - Account: 709825985650 (AWS Marketplace - hardcoded)
```
**Status**: ✅ OK - Official AWS Marketplace account number

## 🟢 EXAMPLES/TESTS - No Action Needed

**Files**: 
- `charts/preview-router/test/*`
- `charts/preview-router/examples/*`
- `charts/judge/demo-values.yaml`
- `charts/judge/tests/*`

**Status**: ✅ OK - Test/example files, not deployed

## Solution: Values Override Pattern

**Strategy**: Keep chart defaults unchanged, override at deployment level

All hardcoded values can be overridden through values files without modifying charts:

```yaml
# values/production.yaml - Complete override example
global:
  domain: mycompany.com

# 1. preview-router - Override ECR registry
preview-router:
  image:
    repository: YOUR_ACCOUNT_ID.dkr.ecr.us-east-1.amazonaws.com/preview-router
  config:
    fallbackUrl: "https://judge.mycompany.com/"
    domainSuffix: "preview.mycompany.com"

# 2. kratos-selfservice-ui-node - Override ingress hosts
kratos-selfservice-ui-node:
  ingress:
    hosts:
      - host: login.mycompany.com
        paths:
          - path: /
            pathType: ImplementationSpecific
    tls:
      - hosts:
          - login.mycompany.com
        secretName: login-tls-secret
  kratosBrowserUrl: "https://kratos.mycompany.com"

# 3. judge-web - Override ingress hosts
judge-web:
  ingress:
    hosts:
      - host: "judge.mycompany.com"
    tls:
      - hosts:
          - judge.mycompany.com
        secretName: judge-tls-secret

# 4. kratos - Override all domain references
kratos:
  ingress:
    public:
      hosts:
        - host: kratos.mycompany.com
    admin:
      hosts:
        - host: kratos-admin.mycompany.com
  kratos:
    config:
      selfservice:
        default_browser_return_url: https://judge.mycompany.com
        allowed_return_urls:
          - https://login.mycompany.com
          - https://kratos.mycompany.com
          - https://judge.mycompany.com
      serve:
        public:
          base_url: https://kratos.mycompany.com

# 5. judge (parent) - Override demo domain
istio:
  domain: mycompany.com

# 6. archivista - Override ingress host
archivista:
  ingress:
    hosts:
      - host: archivista.mycompany.com

# 7. judge-api - Override ingress host
judge-api:
  ingress:
    hosts:
      - host: judge-api.mycompany.com
```

**Key Pattern**: Chart defaults provide localhost/demo values for quick starts. Production deployments override through values hierarchy.

## Summary

**Total Issues**: 7 charts with hardcoded values
**Priority**: Medium - Can be fully overridden at deployment level
**Impact**: Users must provide comprehensive values overrides for production
**Solution**: Document override pattern, keep chart defaults for development ease
