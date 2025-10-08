#!/bin/bash
# Run all domain configuration tests
# Returns 0 if all tests pass, 1 if any fail

set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
FAILED=0

echo "════════════════════════════════════════════════════════"
echo "  Judge Helm Chart - Domain Configuration Test Suite"
echo "════════════════════════════════════════════════════════"
echo

# Test 1: Domain Consistency
echo "Running test 1/3: Domain Consistency"
if "$SCRIPT_DIR/test-domain-consistency.sh"; then
  echo "✅ Test 1 passed"
else
  echo "❌ Test 1 failed"
  FAILED=1
fi
echo

# Test 2: Global Domain Propagation
echo "Running test 2/3: Global Domain Propagation"
if "$SCRIPT_DIR/test-global-domain-propagation.sh"; then
  echo "✅ Test 2 passed"
else
  echo "❌ Test 2 failed"
  FAILED=1
fi
echo

# Test 3: VirtualService Hosts
echo "Running test 3/3: VirtualService Host Consistency"
if "$SCRIPT_DIR/test-virtualservice-hosts.sh"; then
  echo "✅ Test 3 passed"
else
  echo "❌ Test 3 failed"
  FAILED=1
fi
echo

echo "════════════════════════════════════════════════════════"
if [ $FAILED -eq 0 ]; then
  echo "  ✅ All tests passed!"
  echo "════════════════════════════════════════════════════════"
  exit 0
else
  echo "  ❌ Some tests failed. See output above for details."
  echo "════════════════════════════════════════════════════════"
  exit 1
fi
