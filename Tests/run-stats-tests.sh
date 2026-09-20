#!/bin/bash
set -euo pipefail
cd "$(dirname "$0")/.."
test_build_dir=$(mktemp -d /tmp/fullr-stats-tests.XXXXXX)
trap 'rm -rf "$test_build_dir"' EXIT
export DEVELOPER_DIR="${DEVELOPER_DIR:-/Applications/Xcode.app/Contents/Developer}"
xcrun swiftc -parse-as-library -target "$(uname -m)-apple-macos26.0" \
    -default-isolation MainActor -module-cache-path "$test_build_dir/ModuleCache" \
    Fullr/Models/RestaurantStats.swift Fullr/Features/Stats/ClaimStatsViewModel.swift \
    Tests/ClaimStatsViewModelTests.swift -o "$test_build_dir/ClaimStatsViewModelTests"
"$test_build_dir/ClaimStatsViewModelTests"
