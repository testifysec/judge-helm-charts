#!/bin/bash
# Validate Kubernetes resources for namespace consistency, scoping, and API versions
# Usage: ./scripts/validate-resources.sh [manifest-file]

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_DIR="$(cd "${SCRIPT_DIR}/.." && pwd)"

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

# Counters
PASS=0
FAIL=0
WARN=0

# Error tracking
declare -a ERRORS

log_pass() {
    echo -e "${GREEN}✓${NC} $1"
    ((PASS++))
}

log_fail() {
    echo -e "${RED}✗${NC} $1"
    ((FAIL++))
    ERRORS+=("$1")
}

log_warn() {
    echo -e "${YELLOW}⚠${NC} $1"
    ((WARN++))
}

# Extract namespace from manifest
get_namespace() {
    local manifest=$1
    echo "$manifest" | grep -oP '^\s*namespace:\s*\K[^ ]*' | head -1 || echo ""
}

# Extract kind from manifest
get_kind() {
    local manifest=$1
    echo "$manifest" | grep -oP '^kind:\s*\K[^ ]*' | head -1 || echo ""
}

# Extract apiVersion from manifest
get_api_version() {
    local manifest=$1
    echo "$manifest" | grep -oP '^apiVersion:\s*\K[^ ]*' | head -1 || echo ""
}

# Check if resource is cluster-scoped
is_cluster_scoped() {
    local kind=$1
    case "$kind" in
        ClusterRole|ClusterRoleBinding|ClusterNetworkPolicy|PriorityClass|StorageClass|Namespace|VolumeSnapshotClass|CustomResourceDefinition|VolumeAttachment)
            return 0 ;;
        *)
            return 1 ;;
    esac
}

# Check if API version is beta or alpha
has_beta_or_alpha() {
    local api_version=$1
    [[ "$api_version" =~ (v1alpha|v1beta|alpha|beta) ]]
}

# Get allowed beta/alpha APIs (compatibility with older k8s)
is_allowed_beta_or_alpha() {
    local kind=$1
    local api_version=$2

    # Policy/v1beta1 allowed for PDB (backward compat with k8s <1.21)
    if [[ "$kind" == "PodDisruptionBudget" && "$api_version" == "policy/v1beta1" ]]; then
        return 0
    fi

    # Autoscaling/v2beta1 allowed for HPA (backward compat with k8s <1.23)
    if [[ "$kind" == "HorizontalPodAutoscaler" && "$api_version" == "autoscaling/v2beta1" ]]; then
        return 0
    fi

    # Extensions/v1beta1 allowed for NetworkPolicy (very old, but allowed for extreme compat)
    if [[ "$kind" == "NetworkPolicy" && "$api_version" == "extensions/v1beta1" ]]; then
        return 0
    fi

    # Dapr/v1alpha1 allowed for Dapr components (project uses alpha)
    if [[ "$kind" == "Component" && "$api_version" == "dapr.io/v1alpha1" ]]; then
        return 0
    fi

    # Networking.gke.io/v1beta1 allowed for FrontendConfig (GCP stable)
    if [[ "$kind" == "FrontendConfig" && "$api_version" == "networking.gke.io/v1beta1" ]]; then
        return 0
    fi

    # Istio resources allowed at v1beta1 (Istio doesn't use v1 yet)
    if [[ "$api_version" =~ networking\.istio\.io/v1beta1 ]]; then
        return 0
    fi

    return 1
}

# Validate a single resource manifest
validate_resource() {
    local manifest=$1
    local resource_num=$2

    local kind=$(get_kind "$manifest")
    local api_version=$(get_api_version "$manifest")
    local namespace=$(get_namespace "$manifest")

    # Skip resources without kind (comments, etc)
    if [[ -z "$kind" ]]; then
        return
    fi

    # Check namespace scoping
    if is_cluster_scoped "$kind"; then
        # Cluster-scoped resources are allowed but should be rare
        if [[ "$kind" == "ClusterRole" || "$kind" == "ClusterRoleBinding" ]]; then
            log_warn "Resource #$resource_num: $kind (cluster-scoped, should only be in judge-preflight)"
        else
            log_pass "Resource #$resource_num: $kind is cluster-scoped"
        fi
    else
        # Namespace-scoped resources must have namespace
        if [[ -z "$namespace" ]]; then
            log_fail "Resource #$resource_num: $kind has no namespace (must be namespace-scoped)"
        else
            log_pass "Resource #$resource_num: $kind in namespace '$namespace'"
        fi
    fi

    # Check API version
    if has_beta_or_alpha "$api_version"; then
        if is_allowed_beta_or_alpha "$kind" "$api_version"; then
            log_pass "Resource #$resource_num: $kind uses allowed beta/alpha API: $api_version"
        else
            log_fail "Resource #$resource_num: $kind uses disallowed beta/alpha API: $api_version"
        fi
    else
        log_pass "Resource #$resource_num: $kind uses stable API: $api_version"
    fi
}

# Split manifest by --- and validate each resource
validate_manifests() {
    local manifest_file=$1

    if [[ ! -f "$manifest_file" ]]; then
        echo -e "${RED}Error: Manifest file not found: $manifest_file${NC}"
        exit 1
    fi

    echo "Validating resources in: $manifest_file"
    echo ""

    local resource_num=0
    local current_manifest=""

    while IFS= read -r line; do
        if [[ "$line" =~ ^---$ ]]; then
            if [[ -n "$current_manifest" ]]; then
                ((resource_num++))
                validate_resource "$current_manifest" "$resource_num"
            fi
            current_manifest=""
        else
            current_manifest+="$line"$'\n'
        fi
    done < "$manifest_file"

    # Don't forget the last resource
    if [[ -n "$current_manifest" ]]; then
        ((resource_num++))
        validate_resource "$current_manifest" "$resource_num"
    fi

    echo ""
    echo "========================================"
    echo "Validation Summary"
    echo "========================================"
    echo -e "  ${GREEN}Pass:${NC}    $PASS"
    echo -e "  ${YELLOW}Warn:${NC}    $WARN"
    echo -e "  ${RED}Fail:${NC}    $FAIL"
    echo ""

    if [[ $FAIL -gt 0 ]]; then
        echo -e "${RED}FAILED - Errors found:${NC}"
        for error in "${ERRORS[@]}"; do
            echo "  - $error"
        done
        return 1
    else
        echo -e "${GREEN}PASSED - All validations successful${NC}"
        return 0
    fi
}

# Main
if [[ $# -eq 0 ]]; then
    # Default: validate helm template output
    echo "Generating manifests from helm chart..."
    MANIFEST_FILE="/tmp/judge-manifest-validation-$$.yaml"
    helm template judge "$REPO_DIR/charts/judge" -f "$REPO_DIR/values.yaml" > "$MANIFEST_FILE"
    validate_manifests "$MANIFEST_FILE"
    rm -f "$MANIFEST_FILE"
else
    validate_manifests "$1"
fi
