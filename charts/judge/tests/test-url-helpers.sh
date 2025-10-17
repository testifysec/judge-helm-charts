#!/bin/bash
# Test: Verify URL helpers use configurable hostnames
# This test MUST fail initially

set -e

CHART_PATH="charts/judge"
TEMP_TEMPLATE="/tmp/test-url-helpers-$$.yaml"
TEMP_OUTPUT="/tmp/judge-helpers-$$.yaml"
CUSTOM_VALUES="/tmp/custom-helpers-$$.yaml"

echo "=== Test: URL Helper Functions ==="

# Create test template that exercises all URL helpers
cat > "$TEMP_TEMPLATE" <<'EOF'
apiVersion: v1
kind: ConfigMap
metadata:
  name: test-url-helpers
data:
  kratos-url: {{ include "judge.url.kratos" . | quote }}
  login-url: {{ include "judge.url.login" . | quote }}
  judge-url: {{ include "judge.url.judge" . | quote }}
  dex-url: {{ include "judge.url.dex" . | quote }}
  login-error-url: {{ include "judge.url.loginError" . | quote }}
  login-settings-url: {{ include "judge.url.loginSettings" . | quote }}
EOF

# Temporarily add test template
cp "$TEMP_TEMPLATE" "$CHART_PATH/templates/test-url-helpers.yaml"

# Test with default values
echo "Testing with default hostnames..."
helm template test "$CHART_PATH" -f "$CHART_PATH/test-values.yaml" --show-only templates/test-url-helpers.yaml > "$TEMP_OUTPUT" 2>&1 || {
  echo "❌ Default rendering failed"
  rm -f "$TEMP_TEMPLATE" "$TEMP_OUTPUT" "$CHART_PATH/templates/test-url-helpers.yaml"
  exit 1
}

if ! grep -q 'kratos-url: "https://kratos.' "$TEMP_OUTPUT"; then
  echo "❌ Default kratos URL helper failed"
  rm -f "$TEMP_TEMPLATE" "$TEMP_OUTPUT" "$CHART_PATH/templates/test-url-helpers.yaml"
  exit 1
fi

echo "✓ Default URL helpers work"

# Test with custom hostnames
cat > "$CUSTOM_VALUES" <<EOF
global:
  domain: test.com
istio:
  domain: test.com
  hosts:
    kratos: "identity"
    login: "signin"
    web: "portal"
    dex: "oidc-provider"
EOF

echo "Testing with custom hostnames..."
helm template test "$CHART_PATH" -f "$CHART_PATH/test-values.yaml" -f "$CUSTOM_VALUES" --show-only templates/test-url-helpers.yaml > "$TEMP_OUTPUT" 2>&1 || {
  echo "❌ Custom rendering failed"
  rm -f "$TEMP_TEMPLATE" "$TEMP_OUTPUT" "$CUSTOM_VALUES" "$CHART_PATH/templates/test-url-helpers.yaml"
  exit 1
}

# These checks WILL FAIL initially, proving the bug exists
if grep -q 'kratos-url: "https://kratos.test.com"' "$TEMP_OUTPUT"; then
  echo "❌ FAIL: judge.url.kratos still hardcodes 'kratos' subdomain"
  echo "   Expected: https://identity.test.com"
  echo "   Got: $(grep 'kratos-url:' "$TEMP_OUTPUT")"
  rm -f "$TEMP_TEMPLATE" "$TEMP_OUTPUT" "$CUSTOM_VALUES" "$CHART_PATH/templates/test-url-helpers.yaml"
  exit 1
fi

if grep -q 'login-url: "https://signin.test.com"' "$TEMP_OUTPUT"; then
  echo "✓ judge.url.login FIXED - uses custom 'signin' subdomain"
else
  echo "❌ FAIL: judge.url.login doesn't use custom 'signin' subdomain"
  echo "   Got: $(grep 'login-url:' "$TEMP_OUTPUT")"
  rm -f "$TEMP_TEMPLATE" "$TEMP_OUTPUT" "$CUSTOM_VALUES" "$CHART_PATH/templates/test-url-helpers.yaml"
  exit 1
fi

if grep -q 'judge-url: "https://portal.test.com"' "$TEMP_OUTPUT"; then
  echo "✓ judge.url.judge FIXED - uses custom 'portal' subdomain"
else
  echo "❌ FAIL: judge.url.judge doesn't use custom 'portal' subdomain"
  echo "   Got: $(grep 'judge-url:' "$TEMP_OUTPUT")"
  rm -f "$TEMP_TEMPLATE" "$TEMP_OUTPUT" "$CUSTOM_VALUES" "$CHART_PATH/templates/test-url-helpers.yaml"
  exit 1
fi

if grep -q 'dex-url: "https://oidc-provider.test.com"' "$TEMP_OUTPUT"; then
  echo "✓ judge.url.dex FIXED - uses custom 'oidc-provider' subdomain"
else
  echo "❌ FAIL: judge.url.dex doesn't use custom 'oidc-provider' subdomain"
  echo "   Got: $(grep 'dex-url:' "$TEMP_OUTPUT")"
  rm -f "$TEMP_TEMPLATE" "$TEMP_OUTPUT" "$CUSTOM_VALUES" "$CHART_PATH/templates/test-url-helpers.yaml"
  exit 1
fi

# Cleanup
rm -f "$TEMP_TEMPLATE" "$TEMP_OUTPUT" "$CUSTOM_VALUES" "$CHART_PATH/templates/test-url-helpers.yaml"
echo "✅ PASS: URL helpers use configurable hostnames"
exit 0
