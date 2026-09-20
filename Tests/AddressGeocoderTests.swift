import Foundation
import MapKit

// Run with: bash Tests/run-address-geocoder-tests.sh
// Injected lookups keep these regressions independent of Apple's network service.
@main
struct AddressGeocoderTests {
    @MainActor
    static func main() async throws {
        let expected = CLLocationCoordinate2D(latitude: 29.63, longitude: -82.37)
        var calls = 0
        var receivedAddresses: [String] = []
        var receivedRegions: [MKCoordinateRegion?] = []
        let geocoder = AddressGeocoder(lookup: { address, region in
            calls += 1
            receivedAddresses.append(address)
            receivedRegions.append(region)
            try await Task.sleep(for: .milliseconds(10))
            return expected
        })

        let empty = try await geocoder.coordinate(for: " \n ", near: nil)
        let literal = try await geocoder.coordinate(for: "29.63, -82.37", near: nil)
        let invalid = try await geocoder.coordinate(for: "200, -500", near: nil)
        precondition(empty == nil && invalid == nil && calls == 0)
        precondition(literal?.latitude == expected.latitude)

        async let first = geocoder.coordinate(for: "2777 SW ARCHER RD", near: nil)
        async let second = geocoder.coordinate(for: " 2777   sw archer rd\n", near: nil)
        let (one, two) = try await (first, second)
        precondition(one?.longitude == expected.longitude && two?.longitude == expected.longitude)
        precondition(calls == 1, "Concurrent normalized addresses must share one lookup")
        _ = try await geocoder.coordinate(for: "2777 SW ARCHER RD", near: nil)
        precondition(calls == 1, "Repeat fetch must reuse the coordinate")

        _ = try await geocoder.coordinate(for: "12 Main St Apt 34", near: nil)
        precondition(receivedAddresses.contains("12 Main St Apt 34"), "House/unit numbers are not coordinates")
        _ = try await geocoder.coordinate(for: "2777 SW ARCHER RD", near: expected)
        precondition(calls == 3 && receivedRegions.last! != nil, "Location changes must disambiguate the cached address")
        _ = try await geocoder.coordinate(for: "2777 SW ARCHER RD", near: CLLocationCoordinate2D(latitude: 29.631, longitude: -82.371))
        precondition(calls == 3, "Small GPS changes must reuse regional results")

        var now = Date()
        var retryCalls = 0
        let retryGeocoder = AddressGeocoder(lookup: { _, _ in
            retryCalls += 1
            if retryCalls == 1 { throw URLError(.notConnectedToInternet) }
            return expected
        }, now: { now })
        for _ in 0..<2 {
            do {
                _ = try await retryGeocoder.coordinate(for: "2777 SW ARCHER RD", near: nil)
                preconditionFailure("Expected temporary network failure")
            } catch is URLError { }
        }
        precondition(retryCalls == 1)
        now = now.addingTimeInterval(61)
        let retried = try await retryGeocoder.coordinate(for: "2777 SW ARCHER RD", near: nil)
        precondition(retried != nil && retryCalls == 2, "Failures must not be cached forever")

        var missingCalls = 0
        let missingGeocoder = AddressGeocoder(lookup: { _, _ in
            missingCalls += 1
            return nil
        }, now: { now })
        _ = try await missingGeocoder.coordinate(for: "Unknown address", near: nil)
        _ = try await missingGeocoder.coordinate(for: "Unknown address", near: nil)
        precondition(missingCalls == 1)
        now = now.addingTimeInterval(61)
        _ = try await missingGeocoder.coordinate(for: "Unknown address", near: nil)
        precondition(missingCalls == 2)

        var active = 0
        var maximumActive = 0
        let queued = AddressGeocoder(lookup: { _, _ in
            active += 1
            maximumActive = max(maximumActive, active)
            try await Task.sleep(for: .milliseconds(20))
            active -= 1
            return expected
        })
        let canceled = Task { try await queued.coordinate(for: "First address", near: nil) }
        await Task.yield()
        let shared = Task { try await queued.coordinate(for: "First address", near: nil) }
        let different = Task { try await queued.coordinate(for: "Second address", near: nil) }
        canceled.cancel()
        do {
            _ = try await canceled.value
            preconditionFailure("Canceled fetch must not publish its result")
        } catch is CancellationError { }
        let sharedResult = try await shared.value
        let differentResult = try await different.value
        precondition(sharedResult != nil && differentResult != nil)
        precondition(maximumActive == 1, "Distinct network lookups must run serially")

        print("Address geocoding regressions passed: parsing, lookup, deduplication, regional caching, retry, and cancellation.")
    }
}
