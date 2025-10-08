# judge-helm-charts

Helm charts for Judge platform deployment to customer environments.

## Purpose

This repository contains Istio-ready, Vault-integrated Helm charts for deploying the Judge platform to customer environments. The charts are based on the upstream `testifysec/judge` charts with customer-specific modifications for:

- Istio service mesh integration
- HashiCorp Vault PKI integration for Fulcio/TSA certificate management
- Multi-environment deployment support
- Customer-specific networking and security configurations

## ⚠️ CRITICAL: Helm Dependency Management

**Always run `make deps` after modifying any subchart files!**

This repository uses Helm's [file:// dependencies](https://helm.sh/docs/helm/helm_dependency/) which are packaged as `.tgz` files. When you modify source files in subcharts (e.g., `charts/judge-api/templates/deployment.yaml`), the packaged `.tgz` files in `charts/judge/charts/` do NOT automatically update.

### The Problem
- You modify: `charts/judge-api/templates/deployment.yaml` (e.g., add Vault annotations)
- ArgoCD deploys: `charts/judge/charts/judge-api-1.6.0.tgz` (stale version without your changes)
- Result: **Your changes are not deployed!** ❌

### The Solution
**Automated Guards:**
1. **Pre-commit hook**: Auto-runs `make deps` when you commit subchart changes
2. **CI/CD check**: GitHub Actions fails PRs with stale dependencies
3. **Makefile targets**: Manual validation tools

**Manual Workflow:**
```bash
# After modifying any subchart
make deps              # Rebuild all .tgz files
git add charts/judge/charts/*.tgz
git commit -m "your message"

# Check if dependencies are fresh
make check-deps        # Fails if .tgz files are stale

# Validate Vault annotations are present
make validate          # Checks helm template output

# Run all checks
make test             # check-deps + validate
```

### Quick Reference
| Command | Purpose |
|---------|---------|
| `make deps` | Rebuild all Helm dependencies (always run after subchart changes) |
| `make check-deps` | Check if any .tgz files are stale |
| `make validate` | Validate Helm templates and check for Vault annotations |
| `make test` | Run all checks |
| `make help` | Show all available targets |

See [CONTRIBUTING.md](CONTRIBUTING.md) for detailed workflow.

## Repository Structure

```
charts/
├── judge/                    # Umbrella chart for Judge platform
│   ├── Chart.yaml
│   ├── values.yaml
│   └── templates/
│       ├── istio-gateway.yaml
│       ├── istio-virtualservice.yaml
│       └── ...
├── archivista/              # Archivista subchart
├── fulcio/                  # Fulcio subchart with Vault PKI integration
├── rekor/                   # Rekor subchart
├── tsa/                     # TSA subchart with Vault PKI integration
└── spire/                   # SPIRE subchart
```

## Key Features

- **Istio Integration**: Service port naming for protocol detection, Gateway and VirtualService configurations
- **Dapr + Istio Compatibility**: Port exclusion annotations to prevent conflicts
- **MySQL Sidecar Exclusion**: Proper configuration for MySQL CloudSQL proxy
- **Vault PKI**: Integration with HashiCorp Vault for certificate management
- **Multi-Environment**: Support for dev, staging, and production deployments

## Development

Charts in this repository are maintained separately from the upstream Judge charts to allow for customer-specific modifications while maintaining the ability to pull updates from upstream.

## License

Copyright © TestifySec. All rights reserved. Proprietary and confidential.
