#!/bin/bash
set -e

# Smart Defaults Integration Tests
# Tests Chart.yaml dependency conditions that helm unittest cannot test

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

JUDGE_CHART="charts/judge"
TEST_COUNT=0
PASS_COUNT=0
FAIL_COUNT=0

# Helper function to check if a specific Kubernetes resource exists in output
resource_exists() {
    local output="$1"
    local kind="$2"
    local name_pattern="$3"

    # Check if there's a resource of this kind with a name matching the pattern
    echo "$output" | awk "/^kind: $kind\$/,/^---\$/" | grep -q "name:.*$name_pattern"
}

# Helper function to run a test
run_test() {
    local test_name="$1"
    local helm_args="$2"
    local expected_kind="$3"
    local expected_name="$4"
    local should_exist="$5"  # "true" or "false"

    TEST_COUNT=$((TEST_COUNT + 1))

    echo -e "${BLUE}Test $TEST_COUNT: $test_name${NC}"

    # Run helm template
    local output
    output=$(helm template test "$JUDGE_CHART" $helm_args 2>&1)

    local test_passed=true

    if [ "$should_exist" = "true" ]; then
        if ! resource_exists "$output" "$expected_kind" "$expected_name"; then
            echo -e "  ${RED}✗ Expected resource not found: kind=$expected_kind name=$expected_name${NC}"
            test_passed=false
        fi
    else
        if resource_exists "$output" "$expected_kind" "$expected_name"; then
            echo -e "  ${RED}✗ Unexpected resource found: kind=$expected_kind name=$expected_name${NC}"
            test_passed=false
        fi
    fi

    if [ "$test_passed" = true ]; then
        echo -e "  ${GREEN}✓ PASS${NC}"
        PASS_COUNT=$((PASS_COUNT + 1))
    else
        echo -e "  ${RED}✗ FAIL${NC}"
        FAIL_COUNT=$((FAIL_COUNT + 1))
        return 1
    fi

    echo ""
}

echo -e "${YELLOW}╔════════════════════════════════════════════════════════════╗${NC}"
echo -e "${YELLOW}║      Smart Defaults Integration Tests                     ║${NC}"
echo -e "${YELLOW}║      Testing Chart.yaml Dependency Conditions             ║${NC}"
echo -e "${YELLOW}╚════════════════════════════════════════════════════════════╝${NC}"
echo ""

# ============================================================================
# Test Suite 1: Localstack Smart Defaults
# ============================================================================

echo -e "${YELLOW}═══ Localstack Smart Defaults ═══${NC}"
echo ""

run_test \
    "localstack enabled when global.dev=true" \
    "--set global.dev=true --set localstack.enabled=true --set global.domain=test.com" \
    "Deployment" \
    "localstack" \
    "true"

run_test \
    "localstack disabled when global.dev=false (not explicitly enabled)" \
    "--set global.dev=false --set global.domain=test.com" \
    "Deployment" \
    "localstack" \
    "false"

run_test \
    "localstack explicit override: enabled=true overrides dev=false" \
    "--set global.dev=false --set localstack.enabled=true --set global.domain=test.com" \
    "Deployment" \
    "localstack" \
    "true"

run_test \
    "localstack explicit override: enabled=false overrides dev=true" \
    "--set global.dev=true --set localstack.enabled=false --set global.domain=test.com" \
    "Deployment" \
    "localstack" \
    "false"

# ============================================================================
# Test Suite 2: PostgreSQL Smart Defaults
# ============================================================================

echo -e "${YELLOW}═══ PostgreSQL Smart Defaults ═══${NC}"
echo ""

run_test \
    "postgresql enabled when global.dev=true" \
    "--set global.dev=true --set postgresql.enabled=true --set global.domain=test.com" \
    "StatefulSet" \
    "postgresql" \
    "true"

run_test \
    "postgresql disabled when global.dev=false (not explicitly enabled)" \
    "--set global.dev=false --set global.domain=test.com" \
    "StatefulSet" \
    "postgresql" \
    "false"

run_test \
    "postgresql explicit override: enabled=true overrides dev=false" \
    "--set global.dev=false --set postgresql.enabled=true --set global.domain=test.com" \
    "StatefulSet" \
    "postgresql" \
    "true"

run_test \
    "postgresql explicit override: enabled=false overrides dev=true" \
    "--set global.dev=true --set postgresql.enabled=false --set global.domain=test.com" \
    "StatefulSet" \
    "postgresql" \
    "false"

# ============================================================================
# Test Suite 3: Judge-Preflight Disabled by Default
# ============================================================================

echo -e "${YELLOW}═══ Judge-Preflight Disabled by Default ═══${NC}"
echo ""

run_test \
    "judge-preflight disabled by default" \
    "--set global.domain=test.com" \
    "Job" \
    "judge-preflight" \
    "false"

run_test \
    "judge-preflight enabled when explicitly set" \
    "--set judge-preflight.enabled=true --set global.domain=test.com" \
    "Job" \
    "judge-preflight" \
    "true"

# ============================================================================
# Summary
# ============================================================================

echo -e "${YELLOW}╔════════════════════════════════════════════════════════════╗${NC}"
echo -e "${YELLOW}║                    Test Summary                           ║${NC}"
echo -e "${YELLOW}╚════════════════════════════════════════════════════════════╝${NC}"
echo ""
echo -e "Total Tests:  ${BLUE}$TEST_COUNT${NC}"
echo -e "Passed:       ${GREEN}$PASS_COUNT${NC}"

if [ $FAIL_COUNT -gt 0 ]; then
    echo -e "Failed:       ${RED}$FAIL_COUNT${NC}"
    echo ""
    echo -e "${RED}✗ Some integration tests failed${NC}"
    exit 1
else
    echo -e "Failed:       ${GREEN}0${NC}"
    echo ""
    echo -e "${GREEN}✓ All integration tests passed!${NC}"
    exit 0
fi
