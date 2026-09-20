#!/bin/bash
set -euo pipefail
cd "$(dirname "$0")/.."
test_build_dir=$(mktemp -d /tmp/fullr-claim-tests.XXXXXX)
trap 'rm -rf "$test_build_dir"' EXIT
export DEVELOPER_DIR="${DEVELOPER_DIR:-/Applications/Xcode.app/Contents/Developer}"
xcrun swiftc -parse-as-library -target "$(uname -m)-apple-macos26.0" \
    -default-isolation MainActor -module-cache-path "$test_build_dir/ModuleCache" \
    Fullr/Models/AppUser.swift Fullr/Models/FoodOffering.swift Fullr/Models/OfferingFilter.swift \
    Fullr/Models/RestaurantStats.swift \
    Fullr/Services/AuthService.swift Fullr/Services/SupabaseClientProvider.swift \
    Fullr/Services/AddressGeocoder.swift Fullr/Services/FoodOfferingService.swift \
    Tests/OfferClaimTests.swift -o "$test_build_dir/OfferClaimTests"
"$test_build_dir/OfferClaimTests"
