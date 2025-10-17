#!/bin/bash
# Test: Verify hostname customization propagates correctly
# This test MUST fail initially - proving the problem exists

set -e

CHART_PATH="charts/judge"
TEMP_OUTPUT="/tmp/judge-helm-test-$$.yaml"
CUSTOM_VALUES="/tmp/custom-hosts-$$.yaml"

echo "=== Test: Hostname Customization Propagation ==="

# Create custom values with different hostnames
cat > "$CUSTOM_VALUES" <<EOF
global:
  domain: example.com

istio:
  enabled: true
  domain: example.com
  hosts:
    web: "app"         # Changed from "judge"
    login: "auth"      # Changed from "login"
    kratos: "oidc"     # Changed from "kratos"
    dex: "idp"         # Changed from "dex"
EOF

# Render with custom hostnames
helm template test "$CHART_PATH" -f "$CHART_PATH/test-values.yaml" -f "$CUSTOM_VALUES" > "$TEMP_OUTPUT" 2>&1 || {
  echo "❌ FAIL: helm template failed"
  rm -f "$TEMP_OUTPUT" "$CUSTOM_VALUES"
  exit 1
}

# Test 1: VirtualService hosts should use custom names
echo "Checking VirtualService hosts..."
if ! grep -q '"app.example.com"' "$TEMP_OUTPUT"; then
  echo "❌ FAIL: VirtualService should route app.example.com"
  rm -f "$TEMP_OUTPUT" "$CUSTOM_VALUES"
  exit 1
fi
if ! grep -q '"auth.example.com"' "$TEMP_OUTPUT"; then
  echo "❌ FAIL: VirtualService should route auth.example.com"
  rm -f "$TEMP_OUTPUT" "$CUSTOM_VALUES"
  exit 1
fi
echo "✓ VirtualServices use custom hostnames"

# Test 2: Kratos config should use custom hostnames
echo "Checking Kratos configuration..."
if grep -q 'https://login.example.com' "$TEMP_OUTPUT"; then
  echo "❌ FAIL: Kratos config still uses hardcoded 'login' subdomain"
  echo "   Should use 'auth.example.com' from istio.hosts.login"
  rm -f "$TEMP_OUTPUT" "$CUSTOM_VALUES"
  exit 1
fi
if grep -q 'https://judge.example.com' "$TEMP_OUTPUT"; then
  echo "❌ FAIL: Kratos config still uses hardcoded 'judge' subdomain"
  echo "   Should use 'app.example.com' from istio.hosts.web"
  rm -f "$TEMP_OUTPUT" "$CUSTOM_VALUES"
  exit 1
fi
if ! grep -q 'https://auth.example.com' "$TEMP_OUTPUT"; then
  echo "❌ FAIL: Kratos config should use auth.example.com for login URLs"
  rm -f "$TEMP_OUTPUT" "$CUSTOM_VALUES"
  exit 1
fi
if ! grep -q 'https://app.example.com' "$TEMP_OUTPUT"; then
  echo "❌ FAIL: Kratos config should use app.example.com for redirect URLs"
  rm -f "$TEMP_OUTPUT" "$CUSTOM_VALUES"
  exit 1
fi
echo "✓ Kratos config uses custom hostnames"

# Cleanup
rm -f "$TEMP_OUTPUT" "$CUSTOM_VALUES"
echo "✅ PASS: Hostname customization works correctly"
exit 0
