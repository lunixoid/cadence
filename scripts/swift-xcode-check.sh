#!/usr/bin/env bash
# Build Cadence (macOS) and CadenceiOS with the same compiler diagnostics as Xcode.
# Treats warnings as errors. Skip with SKIP_SWIFT_CHECK=1.
set -euo pipefail

if [[ "${SKIP_SWIFT_CHECK:-}" == "1" ]]; then
  echo "swift-xcode-check: skipped (SKIP_SWIFT_CHECK=1)"
  exit 0
fi

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
cd "$ROOT"

DERIVED_DATA="${ROOT}/.build/DerivedData"
mkdir -p "$DERIVED_DATA"

COMMON_FLAGS=(
  -project Cadence.xcodeproj
  -configuration Debug
  -derivedDataPath "$DERIVED_DATA"
  SWIFT_TREAT_WARNINGS_AS_ERRORS=YES
  GCC_TREAT_WARNINGS_AS_ERRORS=YES
)

echo "swift-xcode-check: building Cadence (macOS)…"
xcodebuild \
  -scheme Cadence \
  -destination 'platform=macOS' \
  "${COMMON_FLAGS[@]}" \
  build

echo "swift-xcode-check: building CadenceiOS (iOS Simulator)…"
xcodebuild \
  -scheme CadenceiOS \
  -destination 'generic/platform=iOS Simulator' \
  CODE_SIGNING_ALLOWED=NO \
  "${COMMON_FLAGS[@]}" \
  build

echo "swift-xcode-check: OK"
