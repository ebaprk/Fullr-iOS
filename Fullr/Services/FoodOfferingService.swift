import Foundation
import MapKit
import OSLog

protocol FoodOfferingServicing {
    func fetchOfferings(filter: OfferingFilter) async throws -> [FoodOffering]
    func incrementViews(for offerID: UUID) async throws
}

struct MockFoodOfferingService: FoodOfferingServicing {
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

    private var sampleOfferings: [FoodOffering] {
        [
            FoodOffering(id: UUID(), title: "Fresh bagels and spreads", providerName: "Main Street Bagels", providerType: .restaurant, description: "Assorted plain, sesame, and everything bagels with sealed cream cheese tubs.", pickupWindow: "Today, 4:30-6:00 PM", distanceInMiles: 0.4, quantityDescription: "About 24 servings", price: 3, dietaryTags: [.vegetarian], coordinate: CLLocationCoordinate2D(latitude: 40.7295, longitude: -73.9965), postedAt: Date(), imageURL: URL(string: "https://images.unsplash.com/photo-1585478259715-4d3a5f4f9f1a?w=800")),
            FoodOffering(id: UUID(), title: "Pantry produce boxes", providerName: "Campus Community Pantry", providerType: .pantry, description: "Mixed apples, greens, potatoes, and shelf-stable staples packed for student pickup.", pickupWindow: "Today, 2:00-5:00 PM", distanceInMiles: 0.8, quantityDescription: "12 boxes available", price: 0, dietaryTags: [.vegetarian, .vegan, .glutenFree], coordinate: CLLocationCoordinate2D(latitude: 40.7312, longitude: -73.9912), postedAt: Date(), imageURL: URL(string: "https://images.unsplash.com/photo-1542838132-92c53300491e?w=800")),
            FoodOffering(id: UUID(), title: "Catered rice bowls", providerName: "Union Events Team", providerType: .campus, description: "Leftover individually packed rice bowls from a student org lunch.", pickupWindow: "Today, 1:15-2:15 PM", distanceInMiles: 1.1, quantityDescription: "18 bowls", price: 2.5, dietaryTags: [.vegetarian, .halal], coordinate: CLLocationCoordinate2D(latitude: 40.7277, longitude: -73.9951), postedAt: Date(), imageURL: URL(string: "https://images.unsplash.com/photo-1512058564366-18510be2db19?w=800")),
            FoodOffering(id: UUID(), title: "Cafe sandwiches", providerName: "Northside Market", providerType: .business, description: "Wrapped sandwiches nearing end-of-day freshness, labeled with ingredients.", pickupWindow: "Tomorrow, 9:00-10:30 AM", distanceInMiles: 2.3, quantityDescription: "30 sandwiches", price: 4, dietaryTags: [.kosher], coordinate: CLLocationCoordinate2D(latitude: 40.7362, longitude: -73.9890), postedAt: Date(), imageURL: URL(string: "https://images.unsplash.com/photo-1553909489-cd47e0907980?w=800"), isStudentVerifiedProvider: false)
        ]
    }
}

struct SupabaseFoodOfferingService: FoodOfferingServicing {
    private let client: FullrSupabaseClient?
    private let geocoder: AddressGeocoder
    private static let logger = Logger(subsystem: "com.Fullr", category: "OfferGeocoding")

    init(client: FullrSupabaseClient? = SupabaseClientProvider.makeClient(), geocoder: AddressGeocoder? = nil) {
        self.client = client
        self.geocoder = geocoder ?? AddressGeocoder()
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
