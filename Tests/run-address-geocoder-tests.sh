#!/bin/bash
set -euo pipefail
cd "$(dirname "$0")/.."
test_build_dir=$(mktemp -d /tmp/fullr-geocoding-tests.XXXXXX)
trap 'rm -rf "$test_build_dir"' EXIT
export DEVELOPER_DIR="${DEVELOPER_DIR:-/Applications/Xcode.app/Contents/Developer}"
xcrun swiftc -parse-as-library -target "$(uname -m)-apple-macos26.0" \
    -module-cache-path "$test_build_dir/ModuleCache" \
    Fullr/Services/AddressGeocoder.swift Tests/AddressGeocoderTests.swift \
    -o "$test_build_dir/AddressGeocoderTests"
"$test_build_dir/AddressGeocoderTests"
