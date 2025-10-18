#!/usr/bin/env bash
# IRSA ServiceAccount Validation Test
# Validates that critical ServiceAccounts have correct IRSA annotations when enabled

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
CHART_DIR="$(cd "$SCRIPT_DIR/.." && pwd)"

echo "=== IRSA ServiceAccount Validation Test ==="
echo

# Test 1: IRSA annotations present when enabled
echo "Test 1: Validating IRSA annotations are present when global.aws.irsa.enabled=true"
helm template judge-platform "$CHART_DIR" \
  --set global.aws.accountId=831646886084 \
  --set global.aws.region=us-east-1 \
  --set global.aws.prefix=demo-judge \
  --set global.aws.irsa.enabled=true \
  --set judge-api.serviceAccount.create=true \
  --set archivista.serviceAccount.create=true \
  2>/dev/null > /tmp/irsa-test-1.yaml

# Validate judge-api ServiceAccount has IRSA annotation
if grep -q "arn:aws:iam::831646886084:role/demo-judge-judge-api" /tmp/irsa-test-1.yaml; then
  echo "✓ judge-api ServiceAccount has correct IRSA annotation"
else
  echo "✗ judge-api ServiceAccount missing or incorrect IRSA annotation"
  exit 1
fi

# Validate archivista ServiceAccount has IRSA annotation
if grep -q "arn:aws:iam::831646886084:role/demo-judge-archivista" /tmp/irsa-test-1.yaml; then
  echo "✓ archivista ServiceAccount has correct IRSA annotation"
else
  echo "✗ archivista ServiceAccount missing or incorrect IRSA annotation"
  exit 1
fi

echo

# Test 2: IRSA annotations NOT present when disabled
echo "Test 2: Validating IRSA annotations are NOT present when global.aws.irsa.enabled=false"
helm template judge-platform "$CHART_DIR" \
  --set global.aws.accountId=831646886084 \
  --set global.aws.prefix=demo-judge \
  --set global.aws.irsa.enabled=false \
  --set judge-api.serviceAccount.create=true \
  --set archivista.serviceAccount.create=true \
  2>/dev/null > /tmp/irsa-test-2.yaml

# Validate judge-api ServiceAccount does NOT have IRSA annotation
if grep -q "arn:aws:iam::831646886084:role/demo-judge-judge-api" /tmp/irsa-test-2.yaml; then
  echo "✗ judge-api ServiceAccount should NOT have IRSA annotation when disabled"
  exit 1
else
  echo "✓ judge-api ServiceAccount correctly has no IRSA annotation"
fi

# Validate archivista ServiceAccount does NOT have IRSA annotation
if grep -q "arn:aws:iam::831646886084:role/demo-judge-archivista" /tmp/irsa-test-2.yaml; then
  echo "✗ archivista ServiceAccount should NOT have IRSA annotation when disabled"
  exit 1
else
  echo "✓ archivista ServiceAccount correctly has no IRSA annotation"
fi

echo

# Test 3: Environment-specific IAM role names
echo "Test 3: Validating staging environment uses correct IAM role prefix"
helm template judge-platform "$CHART_DIR" \
  --set global.aws.accountId=831646886084 \
  --set global.aws.prefix=staging-judge \
  --set global.aws.irsa.enabled=true \
  --set judge-api.serviceAccount.create=true \
  2>/dev/null > /tmp/irsa-test-3.yaml

if grep -q "arn:aws:iam::831646886084:role/staging-judge-judge-api" /tmp/irsa-test-3.yaml; then
  echo "✓ Staging environment uses correct IAM role prefix (staging-judge-judge-api)"
else
  echo "✗ Staging environment has incorrect IAM role prefix"
  exit 1
fi

echo

# Test 4: Multi-account support
echo "Test 4: Validating different AWS account ID is used correctly"
helm template judge-platform "$CHART_DIR" \
  --set global.aws.accountId=123456789012 \
  --set global.aws.prefix=customer-judge \
  --set global.aws.irsa.enabled=true \
  --set archivista.serviceAccount.create=true \
  2>/dev/null > /tmp/irsa-test-4.yaml

if grep -q "arn:aws:iam::123456789012:role/customer-judge-archivista" /tmp/irsa-test-4.yaml; then
  echo "✓ Custom AWS account ID (123456789012) is used correctly"
else
  echo "✗ Custom AWS account ID not applied correctly"
  exit 1
fi

echo
echo "=== All IRSA validation tests passed ✓ ==="
rm -f /tmp/irsa-test-*.yaml
