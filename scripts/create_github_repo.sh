#!/bin/bash
# Create the GitHub repo and push initial commit
set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(dirname "$SCRIPT_DIR")"
cd "$PROJECT_ROOT"

echo "==> Creating GitHub repo: mojo-money"
gh repo create mojo-money \
    --public \
    --description "Native macOS/iOS app that extends Monarch Money with powerful automation modules" \
    --source=. \
    --remote=origin \
    --push

echo "==> Done! Repo created and pushed."
gh repo view --web
