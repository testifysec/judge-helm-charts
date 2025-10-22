.PHONY: all deps check-deps validate test clean help

# Configuration
JUDGE_CHART := charts/judge
SUBCHARTS := $(filter-out $(JUDGE_CHART) charts/judge.bak, $(wildcard charts/*))
TGZ_DIR := $(JUDGE_CHART)/charts

# Colors for output
RED := \033[0;31m
GREEN := \033[0;32m
YELLOW := \033[1;33m
NC := \033[0m # No Color

##@ General

help: ## Display this help
	@awk 'BEGIN {FS = ":.*##"; printf "\nUsage:\n  make \033[36m<target>\033[0m\n"} /^[a-zA-Z_-]+:.*?##/ { printf "  \033[36m%-15s\033[0m %s\n", $$1, $$2 } /^##@/ { printf "\n\033[1m%s\033[0m\n", substr($$0, 5) } ' $(MAKEFILE_LIST)

##@ Helm Dependency Management

all: deps test ## Rebuild dependencies and run all tests

deps: ## Rebuild all Helm dependencies (run after modifying subchart files)
	@echo "$(YELLOW)Rebuilding Helm dependencies...$(NC)"
	cd $(JUDGE_CHART) && helm dependency update
	@echo "$(GREEN)✓ Dependencies rebuilt successfully$(NC)"
	@echo ""
	@echo "$(YELLOW)Don't forget to:$(NC)"
	@echo "  1. git add $(TGZ_DIR)/*.tgz"
	@echo "  2. git commit with your changes"

check-deps: ## Check if any .tgz files are stale (older than source files)
	@echo "$(YELLOW)Checking Helm dependency freshness...$(NC)"
	@STALE=0; \
	for chart in $(SUBCHARTS); do \
		chart_name=$$(basename $$chart); \
		chart_yaml="$$chart/Chart.yaml"; \
		version=$$(grep '^version:' $$chart_yaml | awk '{print $$2}' | tr -d '"'); \
		tgz_file="$(TGZ_DIR)/$$chart_name-$$version.tgz"; \
		if [ ! -f "$$tgz_file" ]; then \
			echo "$(RED)✗ Missing: $$tgz_file$(NC)"; \
			STALE=1; \
			continue; \
		fi; \
		tgz_time=$$(stat -f "%m" "$$tgz_file" 2>/dev/null || stat -c "%Y" "$$tgz_file"); \
		newest_source=$$(find $$chart -type f -newer "$$tgz_file" | head -1); \
		if [ -n "$$newest_source" ]; then \
			source_time=$$(stat -f "%m" "$$newest_source" 2>/dev/null || stat -c "%Y" "$$newest_source"); \
			echo "$(RED)✗ STALE: $$tgz_file$(NC)"; \
			echo "  └─ Source file newer: $$newest_source"; \
			STALE=1; \
		else \
			echo "$(GREEN)✓ OK: $$chart_name-$$version.tgz$(NC)"; \
		fi; \
	done; \
	echo ""; \
	if [ $$STALE -eq 1 ]; then \
		echo "$(RED)ERROR: Stale dependencies detected!$(NC)"; \
		echo "$(YELLOW)Run: make deps$(NC)"; \
		exit 1; \
	else \
		echo "$(GREEN)✓ All dependencies are fresh$(NC)"; \
	fi

validate: ## Validate Helm templates
	@echo "$(YELLOW)Validating Helm templates...$(NC)"
	@echo ""
	@echo "Checking helm lint..."
	@if [ -f $(JUDGE_CHART)/test-values.yaml ]; then \
		helm lint $(JUDGE_CHART) -f $(JUDGE_CHART)/test-values.yaml || echo "$(YELLOW)⚠️  Helm lint has warnings$(NC)"; \
	else \
		helm lint $(JUDGE_CHART) || echo "$(YELLOW)⚠️  Helm lint has warnings$(NC)"; \
	fi
	@echo ""
	@echo "$(GREEN)✓ Helm template check completed$(NC)"
	@echo ""
	@echo "$(YELLOW)Note: Using Kubernetes secrets for database credentials (not Vault)$(NC)"
	@echo ""
	@echo "$(GREEN)✓ All validations passed$(NC)"

##@ Validation Checks

validate-service-urls: ## Validate service URL patterns
	@./scripts/validate_service_urls.sh

validate-database: ## Check database separation
	@python3 ./scripts/validate_database_separation.py

validate-external-secrets: ## Validate External Secrets configuration
	@./scripts/validate_external_secrets.sh

validate-hostnames: ## Validate hostname consistency
	@./scripts/validate_hostname_consistency.sh

validate-all: validate validate-service-urls validate-database validate-external-secrets validate-hostnames ## Run all validation checks
	@echo "$(GREEN)✓ All validation checks passed!$(NC)"

##@ Testing

test-unit: ## Run helm unittest for template logic tests
	@echo "$(YELLOW)Running helm unit tests...$(NC)"
	@which helm > /dev/null || (echo "$(RED)Error: helm not installed$(NC)" && exit 1)
	@helm plugin list | grep -q unittest || (echo "$(RED)Error: helm unittest plugin not installed$(NC)" && echo "Install: helm plugin install https://github.com/helm-unittest/helm-unittest" && exit 1)
	@echo ""
	@echo "Running all unit tests..."
	helm unittest $(JUDGE_CHART)
	@echo ""
	@echo "$(GREEN)✓ All unit tests passed$(NC)"

test-unit-smart-defaults: ## Run only smart defaults unit tests
	@echo "$(YELLOW)Running smart defaults unit tests...$(NC)"
	@which helm > /dev/null || (echo "$(RED)Error: helm not installed$(NC)" && exit 1)
	@helm plugin list | grep -q unittest || (echo "$(RED)Error: helm unittest plugin not installed$(NC)" && echo "Install: helm plugin install https://github.com/helm-unittest/helm-unittest" && exit 1)
	helm unittest $(JUDGE_CHART) -f '$(JUDGE_CHART)/tests/smart-defaults_test.yaml'
	@echo "$(GREEN)✓ Smart defaults unit tests passed$(NC)"

test-integration: ## Run integration tests for Chart.yaml dependency conditions
	@echo "$(YELLOW)Running smart defaults integration tests...$(NC)"
	@./scripts/test_smart_defaults_integration.sh
	@echo "$(GREEN)✓ Integration tests passed$(NC)"

test-smart-defaults: test-unit-smart-defaults test-integration ## Run all smart defaults tests (unit + integration)
	@echo ""
	@echo "$(GREEN)✓ All smart defaults tests passed!$(NC)"

test: check-deps test-unit validate-all ## Run all tests (dependencies + unit tests + validations)
	@echo ""
	@echo "$(GREEN)✓ All tests passed!$(NC)"

clean: ## Remove all .tgz files from charts/judge/charts/
	@echo "$(YELLOW)Removing all .tgz files...$(NC)"
	rm -f $(TGZ_DIR)/*.tgz
	@echo "$(GREEN)✓ Cleaned$(NC)"

##@ Development Workflow

watch: ## Watch for changes and auto-rebuild deps (requires fswatch)
	@which fswatch > /dev/null || (echo "$(RED)Error: fswatch not installed$(NC)" && exit 1)
	@echo "$(YELLOW)Watching for changes in charts/ ...$(NC)"
	@echo "$(YELLOW)Press Ctrl+C to stop$(NC)"
	@fswatch -o $(SUBCHARTS) | while read num; do \
		echo ""; \
		echo "$(YELLOW)Change detected, rebuilding...$(NC)"; \
		$(MAKE) deps; \
	done
