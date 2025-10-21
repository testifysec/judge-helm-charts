#!/bin/bash
# Validate that hostnames are consistent across all configurations

set -e

CHART_PATH="charts/judge"
ERRORS=0

echo "=== Validating Hostname Consistency ==="
echo ""

# Run all hostname tests
echo "Running hostname customization test..."
if "$CHART_PATH/tests/test-hostname-customization.sh"; then
    echo "✅ Hostname customization test passed"
else
    echo "❌ Hostname customization test failed"
    ERRORS=$((ERRORS + 1))
fi
echo ""

echo "Running URL helper test..."
if "$CHART_PATH/tests/test-url-helpers.sh"; then
    echo "✅ URL helper test passed"
else
    echo "❌ URL helper test failed"
    ERRORS=$((ERRORS + 1))
fi
echo ""

if [ $ERRORS -eq 0 ]; then
    echo "✅ All hostname consistency tests passed"
    exit 0
else
    echo "❌ Hostname consistency validation failed with $ERRORS errors"
    exit 1
fi
