#!/bin/bash
# Test: Verify all domains in values.yaml match a single pattern
# Expected: FAIL initially (we have hardcoded domains)

set -e

CHART_PATH="/Users/nkennedy/proj/cust/conda/repos/cust-anaconda-helm-charts/charts/judge"
VALUES_FILE="$CHART_PATH/values.yaml"

echo "=== Test: Domain Consistency in values.yaml ==="

# Check if global.domain exists
if ! grep -q "^global:" "$VALUES_FILE"; then
  echo "❌ FAIL: global.domain not defined in values.yaml"
  exit 1
fi

GLOBAL_DOMAIN=$(grep -A5 "^global:" "$VALUES_FILE" | grep "domain:" | head -1 | awk '{print $2}')

if [ -z "$GLOBAL_DOMAIN" ]; then
  echo "❌ FAIL: global.domain is empty or not found"
  exit 1
fi

echo "✓ Found global.domain: $GLOBAL_DOMAIN"

# Extract all domain references (*.testifysec-demo.xyz or *.testifysec.localhost)
DOMAINS=$(grep -oE '[a-z0-9-]+\.(testifysec-demo\.xyz|testifysec\.localhost)' "$VALUES_FILE" | sed 's/^[a-z0-9-]*\.//' | sort -u)

echo "✓ Found domain patterns:"
echo "$DOMAINS"

DOMAIN_COUNT=$(echo "$DOMAINS" | wc -l | tr -d ' ')

if [ "$DOMAIN_COUNT" -ne 1 ]; then
  echo "❌ FAIL: Found $DOMAIN_COUNT different domain patterns (expected 1)"
  echo "   Domains found: $DOMAINS"
  exit 1
fi

FOUND_DOMAIN=$(echo "$DOMAINS" | head -1)
if [ "$FOUND_DOMAIN" != "$GLOBAL_DOMAIN" ]; then
  echo "❌ FAIL: All URLs use '$FOUND_DOMAIN' but global.domain is '$GLOBAL_DOMAIN'"
  exit 1
fi

echo "✅ PASS: All domain references use global.domain ($GLOBAL_DOMAIN)"
exit 0
