#!/bin/bash
# Test: Verify VirtualService hosts use istio.domain consistently
# Expected: PASS (we already created VirtualServices correctly)

set -e

CHART_PATH="/Users/nkennedy/proj/cust/conda/repos/cust-anaconda-helm-charts/charts/judge"
TEMP_OUTPUT="/tmp/judge-helm-template-$$.yaml"

echo "=== Test: VirtualService Host Consistency ==="

# Render the chart
helm template test "$CHART_PATH" --namespace test > "$TEMP_OUTPUT" 2>&1 || {
  echo "❌ FAIL: helm template failed"
  cat "$TEMP_OUTPUT"
  rm -f "$TEMP_OUTPUT"
  exit 1
}

# Extract all VirtualService host values
VS_HOSTS=$(grep -A20 "kind: VirtualService" "$TEMP_OUTPUT" | grep -E "^\s+- \".*\..*\"" | sed 's/.*"\(.*\)"/\1/' | sed 's/^[a-z0-9-]*\.//' | sort -u)

if [ -z "$VS_HOSTS" ]; then
  echo "❌ FAIL: No VirtualService hosts found"
  rm -f "$TEMP_OUTPUT"
  exit 1
fi

echo "✓ Found VirtualService domain patterns:"
echo "$VS_HOSTS"

UNIQUE_COUNT=$(echo "$VS_HOSTS" | wc -l | tr -d ' ')

if [ "$UNIQUE_COUNT" -ne 1 ]; then
  echo "❌ FAIL: VirtualServices use $UNIQUE_COUNT different domains (expected 1)"
  echo "   Domains: $VS_HOSTS"
  rm -f "$TEMP_OUTPUT"
  exit 1
fi

rm -f "$TEMP_OUTPUT"
echo "✅ PASS: All VirtualServices use consistent domain: $(echo $VS_HOSTS)"
exit 0
