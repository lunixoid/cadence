#!/usr/bin/env bash
# Build CadenceiOS for a physical device, install, and launch.
# Picks the first available paired iPhone/iPad unless DEVICE / DEVICE_NAME is set.
#
# Usage:
#   ./scripts/deploy-ios-device.sh
#   DEVICE=00008110-… ./scripts/deploy-ios-device.sh
#   DEVICE_NAME=LunarMax ./scripts/deploy-ios-device.sh
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
cd "$ROOT"

BUNDLE_ID="${BUNDLE_ID:-dev.personal.cadence.roman}"
SCHEME="${SCHEME:-CadenceiOS}"
DERIVED_DATA="${DERIVED_DATA:-${ROOT}/.build/DerivedData-iphoneos}"
APP="${DERIVED_DATA}/Build/Products/Debug-iphoneos/Cadence.app"

resolve_device() {
  if [[ -n "${DEVICE:-}" ]]; then
    printf '%s\n' "$DEVICE"
    return
  fi

  local json
  json="$(mktemp -t cadence-devices.XXXXXX.json)"
  # shellcheck disable=SC2064
  trap "rm -f '$json'" RETURN

  xcrun devicectl list devices --json-output "$json" >/dev/null

  python3 - "$json" "${DEVICE_NAME:-}" <<'PY'
import json, sys

path, name_filter = sys.argv[1], sys.argv[2]
data = json.load(open(path))
devices = data.get("result", {}).get("devices", [])

candidates = []
for d in devices:
    hp = d.get("hardwareProperties") or {}
    dp = d.get("deviceProperties") or {}
    cp = d.get("connectionProperties") or {}
    if hp.get("platform") != "iOS":
        continue
    if hp.get("reality") != "physical":
        continue
    udid = hp.get("udid") or d.get("identifier")
    if not udid:
        continue
    name = dp.get("name") or ""
    if name_filter and name_filter.casefold() not in name.casefold():
        continue
    tunnel = (cp.get("tunnelState") or "").lower()
    transport = (cp.get("transportType") or "").lower()
    boot = (dp.get("bootState") or "").lower()
    # Prefer connected / wired / currently booted devices.
    score = 0
    if tunnel == "connected":
        score += 100
    if transport in ("wired", "usb"):
        score += 10
    if boot == "booted":
        score += 5
    if (cp.get("pairingState") or "").lower() == "paired":
        score += 1
    candidates.append((score, name, udid, tunnel, transport))

if not candidates:
    label = f" matching DEVICE_NAME={name_filter!r}" if name_filter else ""
    print(f"error: no physical iOS device found{label}", file=sys.stderr)
    sys.exit(1)

candidates.sort(key=lambda x: (-x[0], x[1]))
score, name, udid, tunnel, transport = candidates[0]
print(f"deploy-ios-device: using {name} ({udid}) tunnel={tunnel or '?'} transport={transport or '?'}", file=sys.stderr)
if len(candidates) > 1:
    others = ", ".join(f"{n} ({u})" for _, n, u, *_ in candidates[1:])
    print(f"deploy-ios-device: other candidates: {others}", file=sys.stderr)
print(udid)
PY
}

DEVICE_ID="$(resolve_device)"
mkdir -p "$DERIVED_DATA"

echo "deploy-ios-device: building ${SCHEME}…"
xcodebuild \
  -project Cadence.xcodeproj \
  -scheme "$SCHEME" \
  -configuration Debug \
  -destination 'generic/platform=iOS' \
  -derivedDataPath "$DERIVED_DATA" \
  build

if [[ ! -d "$APP" ]]; then
  echo "error: app bundle not found at $APP" >&2
  exit 1
fi

echo "deploy-ios-device: installing…"
xcrun devicectl device install app --device "$DEVICE_ID" "$APP"

echo "deploy-ios-device: launching ${BUNDLE_ID}…"
xcrun devicectl device process launch --device "$DEVICE_ID" "$BUNDLE_ID"

echo "deploy-ios-device: OK"
