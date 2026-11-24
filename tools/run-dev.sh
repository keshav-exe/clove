#!/usr/bin/env bash
set -euo pipefail

# Builds Clove from this checkout and runs it in place of the installed copy,
# for trying changes before they ship. It uses your real settings.
#
#   ./tools/run-dev.sh          build (Debug) and launch
#   ./tools/run-dev.sh --test   run the tests first, launch only if they pass
#
# To go back to the installed Clove, quit this one and open /Applications/Clove.app.

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
cd "$ROOT"
DERIVED="build/DevData"
APP="$DERIVED/Build/Products/Debug/Clove.app"

if [[ "${1:-}" == "--test" ]]; then
  echo "-> Running tests"
  xcodebuild -project Clove.xcodeproj -scheme Clove -derivedDataPath "$DERIVED" test -quiet
fi

echo "-> Building"
xcodebuild -project Clove.xcodeproj -scheme Clove -configuration Debug -derivedDataPath "$DERIVED" build -quiet

# Only one Clove can hold the notch.
if pgrep -x Clove >/dev/null; then
  echo "-> Quitting the running Clove"
  osascript -e 'tell application id "com.kshvbgde.clove" to quit' >/dev/null 2>&1 || true
  for _ in {1..20}; do pgrep -x Clove >/dev/null || break; sleep 0.25; done
  pkill -x Clove 2>/dev/null || true
fi

open "$APP"
echo "ok Running the build from $(git rev-parse --short HEAD)$(git diff --quiet || echo ' plus your uncommitted changes')"
