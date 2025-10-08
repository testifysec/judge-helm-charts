# Contributing to judge-helm-charts

## Development Workflow

### Understanding Helm Dependencies

This repository uses **file:// dependencies** in the umbrella chart (`charts/judge/Chart.yaml`):

```yaml
dependencies:
  - name: judge-api
    version: "1.6.0"
    repository: file://../judge-api
```

When you run `helm dependency update`, Helm packages each subchart into a `.tgz` file stored in `charts/judge/charts/`:

```
charts/judge/charts/
├── judge-api-1.6.0.tgz      # Packaged version
├── archivista-1.6.0.tgz
└── ...
```

**Critical:** ArgoCD deploys the `.tgz` files, NOT the source files in `charts/judge-api/`.

### The Stale Dependency Problem

This is what causes deployments to fail:

1. ✅ You modify: `charts/judge-api/templates/deployment.yaml`
2. ❌ You commit without rebuilding dependencies
3. ❌ The `.tgz` file still contains the OLD version
4. ❌ ArgoCD deploys the stale `.tgz` → your changes are missing!

**Example:** Adding Vault annotations to `deployment.yaml` but forgetting to rebuild means ArgoCD deploys pods WITHOUT Vault injection. This exact issue caused the Vault agent injection bug.

### Automated Guards

We have **three layers of protection** to prevent stale dependencies:

#### 1. Pre-commit Hook (Local)
- **File:** `.git/hooks/pre-commit`
- **Triggers:** When you commit changes to `charts/*/`
- **Action:**
  - Runs `make check-deps`
  - If stale: auto-runs `make deps` and stages `.tgz` files
  - Continues with your commit

#### 2. GitHub Actions (CI/CD)
- **File:** `.github/workflows/helm-deps-check.yml`
- **Triggers:** PRs and pushes to `main` that modify `charts/**`
- **Action:**
  - Runs `make check-deps` and `make validate`
  - **Fails the build** if dependencies are stale
  - Comments on PR with fix instructions

#### 3. Makefile Targets (Manual)
- **File:** `Makefile`
- **Purpose:** Manual validation and rebuilding
- **Targets:** See [Makefile Targets](#makefile-targets) below

### Development Workflow

#### Modifying Subcharts

**Standard workflow when changing ANY file in `charts/` (except `charts/judge/`):**

```bash
# 1. Make your changes
vim charts/judge-api/templates/deployment.yaml

# 2. Rebuild dependencies (CRITICAL!)
make deps

# 3. Stage all changes (source files + .tgz files)
git add charts/judge-api/templates/deployment.yaml
git add charts/judge/charts/*.tgz

# 4. Commit (pre-commit hook will verify)
git commit -m "feat: add Vault agent injection to judge-api"

# 5. Push
git push
```

**The pre-commit hook will automatically rebuild if you forget step 2!**

#### Modifying the Umbrella Chart

If you only modify `charts/judge/` (e.g., updating `values.yaml`, adding new templates), **NO rebuild needed**:

```bash
# Umbrella chart changes don't require dependency rebuild
vim charts/judge/values-prod.yaml
git add charts/judge/values-prod.yaml
git commit -m "chore: update production values"
git push
```

### Makefile Targets

| Target | Description | When to Use |
|--------|-------------|-------------|
| `make deps` | Rebuild all Helm dependencies | **ALWAYS** after modifying subchart files |
| `make check-deps` | Check if .tgz files are stale | Before committing (done automatically) |
| `make validate` | Validate Helm templates + check Vault annotations | After rebuilding deps |
| `make test` | Run all checks (check-deps + validate) | Before pushing |
| `make clean` | Remove all .tgz files | When troubleshooting |
| `make help` | Show all available targets | When you forget commands |
| `make watch` | Auto-rebuild on file changes (requires `fswatch`) | During active development |

### Troubleshooting

#### "My changes aren't showing up in the cluster!"

**Cause:** Stale `.tgz` files.

**Fix:**
```bash
# Check if dependencies are stale
make check-deps

# Rebuild dependencies
make deps

# Commit the updated .tgz files
git add charts/judge/charts/*.tgz
git commit --amend --no-edit
git push --force-with-lease
```

#### "Pre-commit hook isn't running"

**Cause:** Hook not executable or git hooks disabled.

**Fix:**
```bash
# Make hook executable
chmod +x .git/hooks/pre-commit

# Verify hooks are enabled
git config core.hooksPath  # Should be empty or .git/hooks
```

#### "GitHub Actions failing with stale dependencies"

**Cause:** You committed without rebuilding dependencies (and pre-commit hook didn't run).

**Fix:**
```bash
# Local fix
make deps
git add charts/judge/charts/*.tgz
git commit -m "fix: rebuild stale helm dependencies"
git push

# The CI check will pass on the next run
```

#### "How do I know which .tgz file corresponds to which subchart?"

The pattern is: `<subchart-name>-<version>.tgz`

Examples:
- `charts/judge-api/` → `charts/judge/charts/judge-api-1.6.0.tgz`
- `charts/archivista/` → `charts/judge/charts/archivista-1.6.0.tgz`

Versions come from each subchart's `Chart.yaml`:
```yaml
# charts/judge-api/Chart.yaml
version: "1.6.0"
```

### Testing Your Changes

#### Local Helm Template Validation

```bash
# Render templates and check for Vault annotations
make validate

# Or manually:
helm template judge charts/judge -f charts/judge/values-prod.yaml \
  --show-only charts/judge-api/templates/deployment.yaml \
  | grep -A 5 "vault.hashicorp.com"
```

#### Local Deployment (Minikube/Kind)

```bash
# Install/upgrade to local cluster
helm upgrade --install judge charts/judge \
  --namespace judge \
  --create-namespace \
  --values charts/judge/values-dev.yaml

# Verify pods have Vault sidecars
kubectl get pods -n judge -o jsonpath='{range .items[*]}{.metadata.name}{"\t"}{.spec.containers[*].name}{"\n"}{end}'
# Should show: judge-api, vault-agent (if Vault enabled)
```

### Best Practices

1. **Always run `make deps`** after modifying subchart files
2. **Run `make test`** before pushing to catch issues early
3. **Check CI status** before merging PRs
4. **Use `make watch`** during active development (auto-rebuilds on changes)
5. **Commit `.tgz` files** along with source changes (they're tracked in git)
6. **Don't manually edit `.tgz` files** (they're regenerated by `helm dependency update`)

### Architecture Decision: Why file:// Dependencies?

**Why not remote chart repositories?**
- **Pros of file://:**
  - Single source of truth (charts + umbrella in same repo)
  - Atomic commits (source + packaged changes together)
  - Easier local development (no chart server needed)
  - Full version control of all changes

- **Cons of file://:**
  - Manual rebuild required (solved by our guard system)
  - Larger git repo (`.tgz` files are binary)
  - Learning curve for developers (solved by this guide)

**Decision:** file:// dependencies are the right choice for this repo because changes are tightly coupled (e.g., Vault integration touches multiple subcharts). The guard system mitigates the rebuild issue.

### Related Documentation

- [Helm Dependency Management](https://helm.sh/docs/helm/helm_dependency/)
- [ArgoCD Helm Charts](https://argo-cd.readthedocs.io/en/stable/user-guide/helm/)
- [Istio Application Requirements](https://istio.io/latest/docs/ops/deployment/application-requirements/)
- [Vault Agent Injector](https://developer.hashicorp.com/vault/docs/platform/k8s/injector)

### Getting Help

- **Stale dependency issues:** Check this guide's [Troubleshooting](#troubleshooting) section
- **Helm questions:** See [Helm docs](https://helm.sh/docs/)
- **Judge platform issues:** See [testifysec/judge](https://github.com/testifysec/judge)
- **Report bugs:** Open an issue in this repository

## Pull Request Process

1. **Create feature branch:** `git checkout -b feat/your-feature`
2. **Make changes** to subchart files
3. **Run `make deps`** to rebuild dependencies
4. **Run `make test`** to validate
5. **Commit changes** (pre-commit hook will verify)
6. **Push and create PR**
7. **Wait for CI** to pass (GitHub Actions will check dependencies)
8. **Request review** from team
9. **Merge** after approval

## Code Review Checklist

Reviewers should verify:

- [ ] If subchart files changed: corresponding `.tgz` files are updated
- [ ] `make check-deps` passes (CI will verify)
- [ ] `make validate` passes (CI will verify)
- [ ] Helm templates render correctly
- [ ] Changes are documented (if user-facing)
- [ ] Tests pass (if applicable)
