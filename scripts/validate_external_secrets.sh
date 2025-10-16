#!/bin/bash
# Validate External Secrets Operator configuration

set -e

echo "=== Validating External Secrets Configuration ==="

WARNINGS=0
ERRORS=0

# Find all ExternalSecret and SecretStore templates
ES_FILES=$(find charts -name "*external-secret*.yaml" -o -name "*secretstore*.yaml" 2>/dev/null)

if [ -z "$ES_FILES" ]; then
    echo "⚠️  No External Secrets configuration found"
    exit 0
fi

for file in $ES_FILES; do
    echo "Checking $file..."

    # Check for required annotations (ExternalSecret only, not SecretStore)
    if grep -q "kind: ExternalSecret" "$file"; then
        # Check for ArgoCD sync-wave
        if ! grep -q "argocd.argoproj.io/sync-wave" "$file"; then
            echo "⚠️  Missing sync-wave annotation in $file"
            WARNINGS=$((WARNINGS + 1))
        fi

        # Check for proper namespace references
        if ! grep -q "namespace:" "$file"; then
            echo "⚠️  Missing namespace specification in $file"
            WARNINGS=$((WARNINGS + 1))
        fi
    fi

    # Check for SecretStore configuration
    if grep -q "kind: SecretStore" "$file"; then
        # Check for Vault backend
        if grep -q "provider:" "$file"; then
            if ! grep -q "vault:" "$file"; then
                echo "ℹ️  Non-Vault provider in $file"
            fi
        fi

        # SecretStores have auth at the provider level, not top level
        if grep -q "vault:" "$file"; then
            if ! grep -A5 "vault:" "$file" | grep -q "auth:"; then
                echo "❌ Missing auth configuration in Vault provider in $file"
                ERRORS=$((ERRORS + 1))
            fi
        fi
    fi

    # Check Vault paths follow expected pattern - but only for actual path values
    VAULT_PATHS=$(grep "key:" "$file" | sed 's/.*key:\s*//' | tr -d '"' | tr -d "'" | grep -v "^$" | grep -v "{{")

    for path_value in $VAULT_PATHS; do
        # Skip empty values and template variables
        if [ -z "$path_value" ] || [[ "$path_value" =~ ^\{\{ ]]; then
            continue
        fi

        # Check if it follows standard pattern (secret/ or kv/ or database/)
        if [[ ! "$path_value" =~ ^(secret/|kv/|database/) ]]; then
            # Allow demo/kubernetes/* pattern which is common
            if [[ ! "$path_value" =~ ^(demo/|prod/|dev/) ]]; then
                echo "⚠️  Non-standard Vault path: $path_value in $file"
                WARNINGS=$((WARNINGS + 1))
            fi
        fi
    done

    # Check for data transformations
    if grep -q "dataFrom:" "$file"; then
        echo "ℹ️  Found dataFrom in $file - bulk secret import"
    fi

    # Check for secret key references in ExternalSecrets
    if grep -q "kind: ExternalSecret" "$file" && grep -q "remoteRef:" "$file"; then
        # Ensure property is specified when using remoteRef
        if ! grep -A2 "remoteRef:" "$file" | grep -q "property:"; then
            echo "⚠️  Missing property specification in remoteRef in $file"
            WARNINGS=$((WARNINGS + 1))
        fi
    fi
done

# Check for corresponding Kubernetes Secret usage
echo ""
echo "Checking for Secret references in deployments..."

SECRET_REFS=$(grep -r "secretKeyRef:" charts/ --include="*.yaml" | grep -v "#" || true)
if [ -n "$SECRET_REFS" ]; then
    echo "ℹ️  Found Secret references in deployments"

    # Extract secret names (handle both inline and multiline formats)
    SECRET_NAMES=$(echo "$SECRET_REFS" | grep -A1 "secretKeyRef:" | grep "name:" | sed 's/.*name:\s*//' | tr -d '"' | tr -d "'" | grep -v "{{" | sort -u)

    # Check if ExternalSecrets create these secrets
    for secret_name in $SECRET_NAMES; do
        # Skip empty or templated names
        if [ -z "$secret_name" ] || echo "$secret_name" | grep -q "{{"; then
            continue
        fi

        # Check if an ExternalSecret creates this
        if ! grep -r "name: $secret_name" charts/ --include="*external-secret*.yaml" >/dev/null 2>&1; then
            # It might be created by a SecretStore or inline, so just note it
            echo "ℹ️  Secret '$secret_name' referenced (ensure it's created by ESO or exists)"
        fi
    done
fi

# Summary
echo ""
echo "=== External Secrets Validation Summary ==="
echo "Errors: $ERRORS"
echo "Warnings: $WARNINGS"

if [ $ERRORS -gt 0 ]; then
    echo "❌ External Secrets validation failed"
    exit 1
elif [ $WARNINGS -gt 0 ]; then
    echo "⚠️  External Secrets validation passed with warnings"
    exit 0
else
    echo "✅ External Secrets validation passed"
    exit 0
fi