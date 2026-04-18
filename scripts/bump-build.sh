#!/usr/bin/env bash
# Bump CURRENT_PROJECT_VERSION (the build number) in Xcode project settings
# to the current git commit count — monotonically increasing, same on every
# machine, App Store Connect never rejects a higher number.
#
# Run this before `xcodebuild archive`:
#   ./scripts/bump-build.sh
#
# MARKETING_VERSION (user-facing, e.g. "1.0.3") is managed by hand in the
# Xcode project; bump it when you ship a new public version.

set -euo pipefail

cd "$(dirname "$0")/.."

if ! git rev-parse --git-dir >/dev/null 2>&1; then
    echo "error: must be run inside a git checkout" >&2
    exit 1
fi

BUILD=$(git rev-list --count HEAD)
MARKETING=$(xcrun agvtool mvers -terse1 2>/dev/null || echo "unknown")

xcrun agvtool new-version -all "$BUILD" >/dev/null

echo "build number -> $BUILD  (marketing version: $MARKETING)"
