#!/bin/bash
# TCR: Test && Commit || Revert
# Helm charts repo - runs pre-commit hooks (includes helm unittest)

echo "🔍 TCR: Running pre-commit hooks..."

if git add -A && git commit -m "tcr: $(date +%H:%M:%S)"; then
    echo "✅ Tests passed - Changes committed"
else
    git restore .
    git clean -fd
    echo "❌ Tests failed - Changes reverted"
    exit 1
fi
