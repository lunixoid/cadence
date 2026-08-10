#!/usr/bin/env bash
# Install the pre-commit framework hook (requires: brew install pre-commit).
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
cd "$ROOT"

chmod +x scripts/swift-xcode-check.sh scripts/install-git-hooks.sh scripts/deploy-ios-device.sh

if ! command -v pre-commit >/dev/null 2>&1; then
  echo "error: pre-commit not found. Install with: brew install pre-commit" >&2
  exit 1
fi

# Prefer framework hooks in .git/hooks over a custom hooksPath.
git config --unset-all core.hooksPath 2>/dev/null || true

pre-commit install
echo "Git pre-commit installed via pre-commit framework."
echo "Manual run: pre-commit run --all-files"
echo "Emergency skip: SKIP_SWIFT_CHECK=1 git commit …"
