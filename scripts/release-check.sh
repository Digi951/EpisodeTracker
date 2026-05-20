#!/bin/bash
set -euo pipefail

# Release check script for HörspielLog
# Run before tagging a new version to validate both build configurations.

PROJECT="EpisodeTracker.xcodeproj"
SCHEME="EpisodeTracker"
DERIVED_DATA_PATH="${EPISODETRACKER_DERIVED_DATA_PATH:-./DerivedData/ReleaseCheck}"

RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m'

step() { echo -e "\n${YELLOW}=== $1 ===${NC}\n"; }
pass() { echo -e "${GREEN}✓ $1${NC}"; }
fail() { echo -e "${RED}✗ $1${NC}" >&2; exit 1; }

resolve_destination() {
    if [ -n "${EPISODETRACKER_DESTINATION:-}" ]; then
        echo "$EPISODETRACKER_DESTINATION"
        return
    fi

    local simulator_name
    simulator_name=$(xcrun simctl list devices available 2>/dev/null \
        | awk -F '[()]' '/iPhone/ { gsub(/^[ \t]+|[ \t]+$/, "", $1); print $1; exit }')

    if [ -z "$simulator_name" ]; then
        fail "No available iPhone simulator found. Set EPISODETRACKER_DESTINATION to a valid xcodebuild destination."
    fi

    echo "platform=iOS Simulator,name=$simulator_name"
}

DESTINATION="$(resolve_destination)"
echo "Using destination: $DESTINATION"
echo "Using derived data path: $DERIVED_DATA_PATH"

step "1/3: Running tests (Debug)"
if xcodebuild test \
    -project "$PROJECT" \
    -scheme "$SCHEME" \
    -destination "$DESTINATION" \
    -derivedDataPath "$DERIVED_DATA_PATH" \
    -quiet 2>&1; then
    pass "Tests passed (Debug)"
else
    fail "Tests failed (Debug)"
fi

step "2/3: Building Release configuration"
if xcodebuild build \
    -project "$PROJECT" \
    -scheme "$SCHEME" \
    -destination "$DESTINATION" \
    -configuration Release \
    -derivedDataPath "$DERIVED_DATA_PATH" \
    -quiet 2>&1; then
    pass "Release build succeeded"
else
    fail "Release build failed"
fi

step "3/3: Checking for #if DEBUG drift"
DEBUG_FILES=$(grep -rl '#if DEBUG' --include='*.swift' EpisodeTracker/ SettingsView.swift 2>/dev/null || true)
if [ -n "$DEBUG_FILES" ]; then
    echo -e "${YELLOW}Files with #if DEBUG conditionals:${NC}"
    echo "$DEBUG_FILES" | while read -r f; do
        COUNT=$(grep -c '#if DEBUG' "$f")
        echo "  $f ($COUNT occurrence(s))"
    done
    echo ""
    echo "Review these to ensure Debug-only code has Release equivalents."
else
    pass "No #if DEBUG conditionals found"
fi

echo ""
pass "Release check complete — safe to tag."
