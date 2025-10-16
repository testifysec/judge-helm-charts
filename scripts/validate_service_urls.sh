#!/bin/bash
# Validate service URLs follow proper Kubernetes naming patterns

set -e

ERRORS=0

echo "=== Validating Service URL Patterns ==="

# Check for hardcoded service names that won't work with different release names
echo "Checking for hardcoded service names..."

# Pattern 1: demo-judge-judge-* (incorrect concatenation)
if grep -r "demo-judge-judge-" charts/ --include="*values*.yaml" 2>/dev/null; then
    echo "❌ Found hardcoded demo-judge-judge-* service names"
    echo "   These should use {release-name}-judge-{component} pattern"
    ERRORS=$((ERRORS + 1))
fi

# Pattern 2: prod-judge in demo files
if grep -r "prod-judge" charts/ --include="demo-values.yaml" 2>/dev/null; then
    echo "❌ Found prod-judge prefix in demo values files"
    ERRORS=$((ERRORS + 1))
fi

# Pattern 3: Check for proper templating in service URLs
echo "Checking for proper service URL templating..."

# Look for service URLs that should use templates
SERVICE_URLS=$(grep -r "\.svc\.cluster\.local" charts/ --include="*.yaml" 2>/dev/null | grep -v "{{" | grep -v "#" || true)

if [ -n "$SERVICE_URLS" ]; then
    echo "⚠️  Found hardcoded service URLs (should use Helm templates):"
    echo "$SERVICE_URLS" | head -5
fi

# Pattern 4: Check for consistent naming
echo "Checking for consistent service naming..."

# Extract all service references
ARCHIVISTA_REFS=$(grep -r "archivista.*svc\.cluster\.local" charts/ --include="*.yaml" 2>/dev/null | wc -l)
JUDGE_API_REFS=$(grep -r "judge-api.*svc\.cluster\.local" charts/ --include="*.yaml" 2>/dev/null | wc -l)

if [ "$ARCHIVISTA_REFS" -gt 0 ]; then
    echo "ℹ️  Found $ARCHIVISTA_REFS archivista service references"
fi

if [ "$JUDGE_API_REFS" -gt 0 ]; then
    echo "ℹ️  Found $JUDGE_API_REFS judge-api service references"
fi

# Summary
if [ $ERRORS -eq 0 ]; then
    echo "✅ Service URL validation passed"
    exit 0
else
    echo "❌ Service URL validation failed with $ERRORS errors"
    exit 1
fi