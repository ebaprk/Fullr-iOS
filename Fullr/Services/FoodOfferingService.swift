import Foundation
import MapKit
import OSLog
import Observation

protocol FoodOfferingServicing {
    func fetchOfferings(filter: OfferingFilter) async throws -> [FoodOffering]
    func fetchClaimedOfferings() async throws -> [FoodOffering]
    func incrementViews(for offerID: UUID) async throws
    func fetchClaimStatus(for offerID: UUID) async throws -> Bool
    func setClaimStatus(_ claimed: Bool, for offerID: UUID) async throws -> Bool
}

final class MockFoodOfferingService: FoodOfferingServicing {
    private var claims: [UUID: Bool] = [:]

    func fetchClaimedOfferings() async throws -> [FoodOffering] {
        sampleOfferings.filter { claims[$0.id] == true }
    }

    func fetchClaimStatus(for offerID: UUID) async throws -> Bool { claims[offerID] ?? false }

    func setClaimStatus(_ claimed: Bool, for offerID: UUID) async throws -> Bool {
        claims[offerID] = claimed
        return claimed
    }
    func fetchOfferings(filter: OfferingFilter) async throws -> [FoodOffering] {
        sampleOfferings.filter { offering in
            let matchesSearch = filter.searchText.isEmpty || offering.title.localizedStandardContains(filter.searchText) || offering.providerName.localizedStandardContains(filter.searchText)
            let matchesProvider = filter.providerType == nil || offering.providerType == filter.providerType
            let matchesDistance = offering.distanceInMiles <= filter.maximumDistanceInMiles
            let matchesDietary = filter.selectedDietaryTags.isEmpty || filter.selectedDietaryTags.isSubset(of: Set(offering.dietaryTags))
            let matchesVerification = !filter.showOnlyStudentVerifiedProviders || offering.isStudentVerifiedProvider
            return matchesSearch && matchesProvider && matchesDistance && matchesDietary && matchesVerification
        }
    }

    func incrementViews(for offerID: UUID) async throws { }

    private let sampleOfferings: [FoodOffering] = {
        [
            FoodOffering(id: UUID(), title: "Fresh bagels and spreads", providerName: "Main Street Bagels", providerType: .restaurant, description: "Assorted plain, sesame, and everything bagels with sealed cream cheese tubs.", pickupWindow: "Today, 4:30-6:00 PM", distanceInMiles: 0.4, quantityDescription: "About 24 servings", price: 3, dietaryTags: [.vegetarian], coordinate: CLLocationCoordinate2D(latitude: 40.7295, longitude: -73.9965), postedAt: Date(), imageURL: URL(string: "https://images.unsplash.com/photo-1585478259715-4d3a5f4f9f1a?w=800")),
            FoodOffering(id: UUID(), title: "Pantry produce boxes", providerName: "Campus Community Pantry", providerType: .pantry, description: "Mixed apples, greens, potatoes, and shelf-stable staples packed for student pickup.", pickupWindow: "Today, 2:00-5:00 PM", distanceInMiles: 0.8, quantityDescription: "12 boxes available", price: 0, dietaryTags: [.vegetarian, .vegan, .glutenFree], coordinate: CLLocationCoordinate2D(latitude: 40.7312, longitude: -73.9912), postedAt: Date(), imageURL: URL(string: "https://images.unsplash.com/photo-1542838132-92c53300491e?w=800")),
            FoodOffering(id: UUID(), title: "Catered rice bowls", providerName: "Union Events Team", providerType: .campus, description: "Leftover individually packed rice bowls from a student org lunch.", pickupWindow: "Today, 1:15-2:15 PM", distanceInMiles: 1.1, quantityDescription: "18 bowls", price: 2.5, dietaryTags: [.vegetarian, .halal], coordinate: CLLocationCoordinate2D(latitude: 40.7277, longitude: -73.9951), postedAt: Date(), imageURL: URL(string: "https://images.unsplash.com/photo-1512058564366-18510be2db19?w=800")),
            FoodOffering(id: UUID(), title: "Cafe sandwiches", providerName: "Northside Market", providerType: .business, description: "Wrapped sandwiches nearing end-of-day freshness, labeled with ingredients.", pickupWindow: "Tomorrow, 9:00-10:30 AM", distanceInMiles: 2.3, quantityDescription: "30 sandwiches", price: 4, dietaryTags: [.kosher], coordinate: CLLocationCoordinate2D(latitude: 40.7362, longitude: -73.9890), postedAt: Date(), imageURL: URL(string: "https://images.unsplash.com/photo-1553909489-cd47e0907980?w=800"), isStudentVerifiedProvider: false)
        ]
    }()
}

struct SupabaseFoodOfferingService: FoodOfferingServicing {
    private let client: FullrSupabaseClient?
    private let geocoder: AddressGeocoder
    private let sessionProvider: () async throws -> SupabaseStoredSession
    private static let logger = Logger(subsystem: "com.Fullr", category: "OfferGeocoding")

    init(
        client: FullrSupabaseClient? = SupabaseClientProvider.makeClient(),
        geocoder: AddressGeocoder? = nil,
        sessionProvider: @escaping () async throws -> SupabaseStoredSession = { throw AuthenticationError.signInRequired }
    ) {
        self.client = client
        self.geocoder = geocoder ?? AddressGeocoder()
        self.sessionProvider = sessionProvider
    }

    func fetchClaimStatus(for offerID: UUID) async throws -> Bool {
        guard let client else { throw AuthenticationError.missingSupabaseConfiguration }
        return try await client.fetchClaimStatus(for: offerID, session: sessionProvider())
    }

    func setClaimStatus(_ claimed: Bool, for offerID: UUID) async throws -> Bool {
        guard let client else { throw AuthenticationError.missingSupabaseConfiguration }
        return try await client.setClaimStatus(claimed, for: offerID, session: sessionProvider())
    }

    func fetchClaimedOfferings() async throws -> [FoodOffering] {
        guard let client else { throw AuthenticationError.missingSupabaseConfiguration }
        let offers = try await client.fetchClaimedOffers(session: sessionProvider())
        guard !offers.isEmpty else { return [] }
        let stores = try await client.fetchStores()
        let storesByID = Dictionary(uniqueKeysWithValues: stores.map { ($0.id, $0) })
        var offerings: [FoodOffering] = []
        for offer in offers {
            try Task.checkCancellation()
            guard let store = storesByID[offer.storeID] else {
                throw AuthenticationError.supabaseRequestFailed("A claimed offer’s provider could not be loaded. Please try again.")
            }
            // Keep claimed offers even when they have expired or their address
            // cannot be geocoded. Discovery filters do not apply to this list.
            let coordinate = try? await geocoder.coordinate(for: store.address, near: nil)
            try Task.checkCancellation()
            var offering = offer.foodOffering(store: store, coordinate: coordinate ?? CLLocationCoordinate2D(), userCoordinate: nil)
            offering.hasPickupCoordinate = coordinate != nil
            offerings.append(offering)
        }
        return offerings
    }

    func fetchOfferings(filter: OfferingFilter) async throws -> [FoodOffering] {
        guard let client else { throw AuthenticationError.missingSupabaseConfiguration }
        let offers = try await client.fetchOffers().filter(\.isAvailable)
        let stores = try await client.fetchStores()
        let storesByID = Dictionary(uniqueKeysWithValues: stores.map { ($0.id, $0) })

        var offerings: [FoodOffering] = []
        var resolvedLocationCount = 0
        var unresolvedLocationCount = 0
        for offer in offers {
            try Task.checkCancellation()
            guard let store = storesByID[offer.storeID] else { continue }
            let coordinate: CLLocationCoordinate2D
            do {
                guard let resolved = try await geocoder.coordinate(for: store.address, near: filter.userCoordinate) else {
                    unresolvedLocationCount += 1
                    Self.logger.notice("No location found for store \(store.id)")
                    continue
                }
                coordinate = resolved
                resolvedLocationCount += 1
            } catch {
                try Task.checkCancellation()
                unresolvedLocationCount += 1
                Self.logger.error("Location lookup failed for store \(store.id): \(error.localizedDescription)")
                continue
            }

            let offering = offer.foodOffering(store: store, coordinate: coordinate, userCoordinate: filter.userCoordinate)
            if matches(offering, filter: filter) {
                offerings.append(offering)
            }
        }

        try Task.checkCancellation()
        if resolvedLocationCount == 0, unresolvedLocationCount > 0 {
            throw OfferingLocationError.unavailable
        }
        return offerings.sorted { $0.distanceInMiles < $1.distanceInMiles }
    }

    func incrementViews(for offerID: UUID) async throws {
        guard let client else { throw AuthenticationError.missingSupabaseConfiguration }
        try await client.incrementOfferViews(for: offerID)
    }

    private func matches(_ offering: FoodOffering, filter: OfferingFilter) -> Bool {
        let matchesSearch = filter.searchText.isEmpty
            || offering.title.localizedStandardContains(filter.searchText)
            || offering.providerName.localizedStandardContains(filter.searchText)
            || offering.description.localizedStandardContains(filter.searchText)
        let matchesProvider = filter.providerType == nil || offering.providerType == filter.providerType
        let matchesDistance = filter.userCoordinate == nil || offering.distanceInMiles <= filter.maximumDistanceInMiles
        let matchesDietary = filter.selectedDietaryTags.isEmpty || filter.selectedDietaryTags.isSubset(of: Set(offering.dietaryTags))
        let matchesVerification = !filter.showOnlyStudentVerifiedProviders || offering.isStudentVerifiedProvider
        return matchesSearch && matchesProvider && matchesDistance && matchesDietary && matchesVerification
    }
}

private enum OfferingLocationError: LocalizedError {
    case unavailable

    var errorDescription: String? {
        "Unable to locate the pickup addresses. Check your connection and try again. Addresses should include a city, state, or ZIP code."
    }
}

@MainActor
@Observable
final class OfferClaimViewModel {
    private let offerID: UUID
    private let service: FoodOfferingServicing
    private(set) var claimed: Bool?
    private(set) var isLoading = true
    private(set) var isSaving = false
    private(set) var hasLoaded = false
    private(set) var errorMessage: String?

    init(offerID: UUID, service: FoodOfferingServicing) {
        self.offerID = offerID
        self.service = service
    }

    func load() async {
        guard !isSaving else { return }
        isLoading = true
        errorMessage = nil
        defer { isLoading = false }
        do {
            let status = try await service.fetchClaimStatus(for: offerID)
            try Task.checkCancellation()
            claimed = status
            hasLoaded = true
        } catch {
            guard !Task.isCancelled else { return }
            hasLoaded = false
            errorMessage = "We couldn’t load your claim status. Please try again."
        }
    }

    func save(_ newValue: Bool) async {
        guard hasLoaded, !isLoading, !isSaving, claimed != newValue else { return }
        isSaving = true
        errorMessage = nil
        defer { isSaving = false }
        do {
            claimed = try await service.setClaimStatus(newValue, for: offerID)
            NotificationCenter.default.post(name: .offerClaimStatusDidChange, object: nil)
        } catch {
            errorMessage = "We couldn’t save your answer. Please try again."
        }
    }
}

extension Notification.Name {
    static let offerClaimStatusDidChange = Notification.Name("offerClaimStatusDidChange")
}

@MainActor
@Observable
final class ClaimedOffersViewModel {
    private let service: FoodOfferingServicing
    private var loadGeneration = 0
    private(set) var offerings: [FoodOffering] = []
    private(set) var isLoading = true
    private(set) var errorMessage: String?

    init(service: FoodOfferingServicing) {
        self.service = service
    }

    func load() async {
        loadGeneration += 1
        let generation = loadGeneration
        isLoading = true
        errorMessage = nil
        defer { if generation == loadGeneration { isLoading = false } }
        do {
            let fetched = try await service.fetchClaimedOfferings()
            try Task.checkCancellation()
            guard generation == loadGeneration else { return }
            offerings = fetched
        } catch {
            guard generation == loadGeneration, !Task.isCancelled else { return }
            errorMessage = "We couldn’t load your claimed offers. Please try again."
        }
    }
}
