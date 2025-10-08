#!/bin/bash
# Test: Verify istio.domain matches global.domain
# Expected: FAIL initially (they're separate values)

set -e

CHART_PATH="/Users/nkennedy/proj/cust/conda/repos/cust-anaconda-helm-charts/charts/judge"
VALUES_FILE="$CHART_PATH/values.yaml"

echo "=== Test: Global Domain Propagation ==="

# Extract global.domain
GLOBAL_DOMAIN=$(grep -A10 "^global:" "$VALUES_FILE" | grep "domain:" | head -1 | awk '{print $2}')

if [ -z "$GLOBAL_DOMAIN" ]; then
  echo "❌ FAIL: global.domain not found"
  exit 1
fi

echo "✓ global.domain = $GLOBAL_DOMAIN"

# Extract istio.domain
ISTIO_DOMAIN=$(grep -A5 "^istio:" "$VALUES_FILE" | grep "domain:" | head -1 | awk '{print $2}')

if [ -z "$ISTIO_DOMAIN" ]; then
  echo "❌ FAIL: istio.domain not found"
  exit 1
fi

echo "✓ istio.domain = $ISTIO_DOMAIN"

if [ "$GLOBAL_DOMAIN" != "$ISTIO_DOMAIN" ]; then
  echo "❌ FAIL: global.domain ($GLOBAL_DOMAIN) != istio.domain ($ISTIO_DOMAIN)"
  echo "   These MUST match for consistency"
  exit 1
fi

echo "✅ PASS: istio.domain matches global.domain ($GLOBAL_DOMAIN)"
exit 0
