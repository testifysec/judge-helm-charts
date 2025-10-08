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
	helm lint $(JUDGE_CHART)
	@echo ""
	@echo "$(GREEN)✓ Helm templates validated successfully$(NC)"
	@echo ""
	@echo "$(YELLOW)Note: Using Kubernetes secrets for database credentials (not Vault)$(NC)"
	@echo ""
	@echo "$(GREEN)✓ All validations passed$(NC)"

test: check-deps validate ## Run all tests (dependency freshness + template validation)
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
