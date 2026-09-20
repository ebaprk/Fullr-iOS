import Foundation
import MapKit

/// Shared by Discover and Map through their offering service.
@MainActor
final class AddressGeocoder {
    typealias Lookup = @MainActor (String, MKCoordinateRegion?) async throws -> CLLocationCoordinate2D?

    private struct CacheEntry {
        let result: Result<CLLocationCoordinate2D?, Error>
        let expiresAt: Date
    }

    private let lookup: Lookup
    private let now: () -> Date
    private var cache: [String: CacheEntry] = [:]
    private var pending: [String: Task<CLLocationCoordinate2D?, Error>] = [:]
    private var queue: Task<Void, Never>?

    init(lookup: Lookup? = nil, now: @escaping () -> Date = Date.init) {
        self.lookup = lookup ?? Self.lookupAddress
        self.now = now
    }

    func coordinate(for address: String, near userCoordinate: CLLocationCoordinate2D?) async throws -> CLLocationCoordinate2D? {
        try Task.checkCancellation()
        let address = address.split(whereSeparator: \.isWhitespace).joined(separator: " ")
        guard !address.isEmpty else { return nil }

        // Only accept a whole numeric pair. Street numbers and ZIP codes must
        // never be mistaken for latitude/longitude.
        if let pair = try? Regex(#"(-?\d+(?:\.\d+)?),\s*(-?\d+(?:\.\d+)?)"#),
           let match = address.wholeMatch(of: pair),
           let latitude = Double(String(match.output[1].substring ?? "")),
           let longitude = Double(String(match.output[2].substring ?? "")) {
            let coordinate = CLLocationCoordinate2D(latitude: latitude, longitude: longitude)
            return CLLocationCoordinate2DIsValid(coordinate) ? coordinate : nil
        }

        // A stable regional hint disambiguates short addresses and avoids
        // repeating lookups for small GPS changes. No permission is required
        // to geocode; without a user location, MapKit searches globally.
        let region = userCoordinate.flatMap { coordinate -> MKCoordinateRegion? in
            guard CLLocationCoordinate2DIsValid(coordinate) else { return nil }
            return MKCoordinateRegion(
                center: CLLocationCoordinate2D(
                    latitude: (coordinate.latitude * 2).rounded() / 2,
                    longitude: (coordinate.longitude * 2).rounded() / 2
                ),
                span: MKCoordinateSpan(latitudeDelta: 2, longitudeDelta: 2)
            )
        }
        let context = region.map { "\($0.center.latitude),\($0.center.longitude)" } ?? "global"
        let key = "\(address.lowercased())|\(context)"
        cache = cache.filter { $0.value.expiresAt > now() }
        if let cached = cache[key] { return try cached.result.get() }

        if let task = pending[key] {
            let result = await task.result
            try Task.checkCancellation()
            return try result.get()
        }

        // Serialize distinct lookups and share identical in-flight requests.
        // A canceled screen load must not cancel a lookup another screen needs.
        let previous = queue
        let task = Task { @MainActor [lookup] in
            await previous?.value
            let coordinate = try await lookup(address, region)
            guard let coordinate, CLLocationCoordinate2DIsValid(coordinate) else { return nil as CLLocationCoordinate2D? }
            return coordinate
        }
        pending[key] = task
        queue = Task { _ = await task.result }
        let result = await task.result
        pending[key] = nil
        // Retry failures/no matches after a minute, including temporary network
        // errors. Successful results are reused for the current app session.
        let lifetime: TimeInterval
        if case .success(.some) = result { lifetime = 24 * 60 * 60 } else { lifetime = 60 }
        if cache.count >= 500 { cache.removeAll(keepingCapacity: true) }
        cache[key] = CacheEntry(result: result, expiresAt: now().addingTimeInterval(lifetime))
        try Task.checkCancellation()
        return try result.get()
    }

    private static func lookupAddress(_ address: String, region: MKCoordinateRegion?) async throws -> CLLocationCoordinate2D? {
        guard let request = MKGeocodingRequest(addressString: address) else { return nil }
        if let region { request.region = region }
        return try await request.mapItems.first?.location.coordinate
    }
}
