# Smart Defaults Pattern

## Overview

The Judge Helm chart uses a **Smart Defaults Pattern** to minimize configuration boilerplate while maintaining full customizability. Configuration values automatically adapt based on context (dev vs production, cloud provider, etc.) without requiring explicit settings.

## Key Principles

1. **Single Source of Truth**: All configuration under `global.*` hierarchy
2. **Automatic Context Detection**: Smart defaults based on `global.dev`, `global.mode`, etc.
3. **Explicit Override**: Users can always override smart defaults
4. **Fail-Safe Defaults**: Conservative defaults that work out of the box

## Smart Defaults in Action

### 1. Istio Configuration Consolidation

**Problem**: Duplicate configuration between root-level `istio:` and `global.istio:`

**Solution**: Single configuration source under `global.istio`

```yaml
# ❌ Before (duplicate config)
global:
  domain: example.com
istio:
  enabled: true
  domain: example.com  # Duplicate!

# ✅ After (single source)
global:
  domain: example.com
  istio:
    enabled: true
    # domain inherited from global.domain
```

**Implementation**:
- All templates reference `global.istio` only
- Removed fallback logic from helpers
- Version: 1.8.24

### 2. Dev Infrastructure Auto-Configuration

**Problem**: Users had to explicitly enable/disable localstack and postgresql for each environment

**Solution**: Multi-condition dependency enablement based on `global.dev`

```yaml
# ❌ Before (explicit everywhere)
global:
  dev: true
localstack:
  enabled: true  # Had to set
postgresql:
  enabled: true  # Had to set

# ✅ After (smart defaults)
global:
  dev: true
# localstack and postgresql automatically enabled!
```

**Implementation**:
- Chart.yaml: `condition: localstack.enabled,global.dev`
- Helm evaluates conditions with OR logic
- Enabled if EITHER condition is true
- Version: 1.8.25

**How It Works**:

```yaml
# Chart.yaml
dependencies:
  - name: localstack
    condition: localstack.enabled,global.dev
    # Enabled if: localstack.enabled=true OR global.dev=true
```

**Behavior Matrix**:

| global.dev | localstack.enabled | Result |
|------------|-------------------|---------|
| true       | (not set)         | ✅ Enabled |
| false      | (not set)         | ❌ Disabled |
| false      | true              | ✅ Enabled (explicit override) |
| true       | false             | ❌ Disabled (explicit override) |

### 3. Judge-Preflight Disabled by Default

**Problem**: Pre-flight validation slowed down dev iterations

**Solution**: Opt-in validation for production

```yaml
# ❌ Before (always ran)
judge-preflight:
  enabled: true  # Default

# ✅ After (opt-in)
# (nothing needed - disabled by default)

# Production:
judge-preflight:
  enabled: true  # Explicit opt-in
```

**Implementation**:
- values.yaml: `judge-preflight.enabled: false`
- Version: 1.8.26

## Configuration Reduction

### Before Smart Defaults

```yaml
global:
  domain: example.com
  dev: false

istio:
  enabled: true
  domain: example.com
  tlsSecretName: wildcard-tls
  ingressGatewaySelector:
    istio: ingress
  hosts:
    web: "judge"
    api: "api"

localstack:
  enabled: false

postgresql:
  enabled: false

judge-preflight:
  enabled: false
```

**Lines**: 23

### After Smart Defaults

```yaml
global:
  domain: example.com
  dev: false

  istio:
    enabled: true
    tlsSecretName: wildcard-tls
    ingressGatewaySelector:
      istio: ingress
    hosts:
      web: "judge"
      api: "api"
```

**Lines**: 12 (48% reduction!)

## Testing Smart Defaults

Smart defaults are tested using a **two-tier testing strategy** because different types of smart defaults require different testing approaches.

### Two-Tier Testing Strategy

#### Tier 1: Unit Tests (helm unittest)
**What it tests**: Template-level conditionals and logic
**Tool**: helm unittest plugin
**Speed**: Fast (~40ms)

Helm unittest can test template rendering logic (like `{{- if .Values.global.istio.enabled }}`), but **cannot** test Chart.yaml dependency `condition` fields because those are evaluated during chart installation, not template rendering.

**Tests covered**:
- ✅ Istio configuration consolidation (`global.istio.enabled` template conditional)
- ✅ Domain inheritance (`global.domain` value propagation)
- ✅ Template rendering with minimal configuration

**Tests NOT covered**:
- ❌ Localstack auto-enable (Chart.yaml `condition: localstack.enabled,global.dev`)
- ❌ PostgreSQL auto-enable (Chart.yaml `condition: postgresql.enabled,global.dev`)
- ❌ Judge-preflight disabled by default (Chart.yaml `condition: judge-preflight.enabled`)

#### Tier 2: Integration Tests (bash script)
**What it tests**: Chart.yaml dependency conditions
**Tool**: bash script using `helm template` with actual dependency resolution
**Speed**: Slower (~1-2s per test)

Integration tests use real `helm template` commands with subcharts to verify Chart.yaml `condition` fields work correctly.

**Tests covered**:
- ✅ Localstack enabled when `global.dev=true`
- ✅ PostgreSQL enabled when `global.dev=true`
- ✅ Both disabled when `global.dev=false`
- ✅ Explicit overrides (`localstack.enabled=true/false`)
- ✅ Judge-preflight disabled by default
- ✅ Combined smart defaults scenarios

### Running Tests

**Run all smart defaults tests (unit + integration)**:
```bash
make test-smart-defaults
```

**Run only unit tests (fast)**:
```bash
make test-unit-smart-defaults
# or directly:
helm unittest charts/judge -f 'charts/judge/tests/smart-defaults_test.yaml'
```

**Run only integration tests**:
```bash
make test-integration
# or directly:
./scripts/test_smart_defaults_integration.sh
```

**Run all tests (including other chart tests)**:
```bash
make test
```

### Test Results Example

**Unit Tests (4 tests)**:
```
✓ should NOT render Istio resources when disabled
✓ should render Istio resources with global.istio config
✓ should use global.domain for Istio hosts
✓ should work with absolute minimal configuration
```

**Integration Tests (12 tests)**:
```
✓ localstack enabled when global.dev=true
✓ localstack disabled when global.dev=false
✓ localstack explicit override: enabled=true overrides dev=false
✓ localstack explicit override: enabled=false overrides dev=true
✓ postgresql enabled when global.dev=true
✓ postgresql disabled when global.dev=false
✓ postgresql explicit override: enabled=true overrides dev=false
✓ postgresql explicit override: enabled=false overrides dev=true
✓ judge-preflight disabled by default
✓ judge-preflight enabled when explicitly set
✓ dev mode enables both localstack and postgresql
✓ production mode disables both localstack and postgresql
```

### Manual Verification (Optional)

You can manually verify smart defaults work as expected:

**Test dev mode auto-enables localstack/postgresql**:
```bash
helm template test charts/judge --set global.dev=true --set localstack.enabled=true --set postgresql.enabled=true --set global.domain=test.com | grep -E "(localstack|postgresql)"
```

**Test production mode disables them**:
```bash
helm template test charts/judge --set global.dev=false --set global.domain=test.com | grep -E "(localstack|postgresql)"
# Should return no results
```

**Test explicit override works**:
```bash
helm template test charts/judge --set global.dev=false --set localstack.enabled=true --set global.domain=test.com | grep localstack
# Should find localstack resources
```

## Migration Guide

### Breaking Changes

**Istio Configuration** (v1.8.24):

```yaml
# Old (no longer supported)
istio:
  enabled: true
  domain: example.com

# New (required)
global:
  domain: example.com
  istio:
    enabled: true
```

### Non-Breaking Changes

**Dev Infrastructure** (v1.8.25):
- Existing `localstack.enabled: false` still works
- Can remove for cleaner config
- Smart defaults apply when not explicitly set

**Preflight** (v1.8.26):
- Existing `judge-preflight.enabled: false` still works
- Can remove for cleaner config
- New default is disabled

## Best Practices

### 1. Rely on Smart Defaults

**Do**:
```yaml
global:
  dev: true  # Enough to enable localstack/postgresql
```

**Don't**:
```yaml
global:
  dev: true
localstack:
  enabled: true  # Redundant!
postgresql:
  enabled: true  # Redundant!
```

### 2. Override Only When Needed

**Do**:
```yaml
global:
  dev: true
localstack:
  enabled: false  # Specific reason to disable
```

**Don't**:
```yaml
global:
  dev: false
localstack:
  enabled: false  # Redundant - already disabled by dev=false
```

### 3. Document Overrides

```yaml
global:
  dev: true
localstack:
  enabled: false  # OVERRIDE: Using external LocalStack for testing
  # Comment explains why overriding smart default
```

## Technical Implementation

### Helm Multi-Condition Pattern

Helm supports comma-separated conditions with OR semantics:

```yaml
dependencies:
  - name: subchart
    condition: subchart.enabled,global.someFlag
```

Evaluation:
1. Check if `subchart.enabled` exists and is truthy → Enable
2. Otherwise, check if `global.someFlag` exists and is truthy → Enable
3. Otherwise → Disable (or use subchart's default)

### Template Helper Pattern

```go
{{- define "judge.mode" -}}
{{- if .Values.global.mode -}}
{{- .Values.global.mode -}}
{{- else if .Values.global.dev -}}
dev
{{- else -}}
aws
{{- end -}}
{{- end -}}
```

This enables:
```go
{{- if eq (include "judge.mode" .) "dev" -}}
  # Dev-specific logic
{{- end -}}
```

## Future Enhancements

Potential smart defaults for future releases:

1. **Cloud Provider Auto-Detection**: Detect EKS/GKE/AKS and configure accordingly
2. **Resource Auto-Scaling**: Adjust requests/limits based on global.environment
3. **Feature Flags**: Enable/disable features based on global.tier (community/enterprise)
4. **Secret Management**: Auto-detect vault/ESO and configure secret sync

## References

- [Helm Chart Dependencies](https://helm.sh/docs/chart_best_practices/dependencies/)
- [Helm Conditions and Tags](https://helm.sh/docs/chart_best_practices/dependencies/#conditions-and-tags)
- [Configuration Pattern Best Practices](https://helm.sh/docs/chart_best_practices/values/)

## Changelog

| Version | Change | Impact |
|---------|--------|--------|
| 1.8.24 | Istio consolidation | Breaking: Root-level istio removed |
| 1.8.25 | Dev infrastructure smart defaults | Non-breaking: Can remove explicit flags |
| 1.8.26 | Preflight disabled by default | Non-breaking: Can remove explicit flags |
