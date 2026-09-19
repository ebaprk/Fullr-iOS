import Foundation
import MapKit

protocol FoodOfferingServicing {
    func fetchOfferings(filter: OfferingFilter) async throws -> [FoodOffering]
}

struct MockFoodOfferingService: FoodOfferingServicing {
    func fetchOfferings(filter: OfferingFilter) async throws -> [FoodOffering] {
        sampleOfferings.filter { offering in
            let matchesSearch = filter.searchText.isEmpty || offering.title.localizedStandardContains(filter.searchText) || offering.providerName.localizedStandardContains(filter.searchText)
            let matchesProvider = filter.providerType == nil || offering.providerType == filter.providerType
            let matchesDistance = offering.distanceInMiles <= filter.maximumDistanceInMiles
            let matchesDietary = filter.selectedDietaryTags.isEmpty || filter.selectedDietaryTags.isSubset(of: Set(offering.dietaryTags))
            return matchesSearch && matchesProvider && matchesDistance && matchesDietary
        }
    }

    private var sampleOfferings: [FoodOffering] {
        [
            FoodOffering(id: UUID(), title: "Fresh bagels and spreads", providerName: "Main Street Bagels", providerType: .restaurant, description: "Assorted plain, sesame, and everything bagels with sealed cream cheese tubs.", pickupWindow: "Today, 4:30-6:00 PM", distanceInMiles: 0.4, quantityDescription: "About 24 servings", dietaryTags: [.vegetarian], coordinate: CLLocationCoordinate2D(latitude: 40.7295, longitude: -73.9965), postedAt: Date(), imageURL: URL(string: "https://images.unsplash.com/photo-1585478259715-4d3a5f4f9f1a?w=800")),
            FoodOffering(id: UUID(), title: "Pantry produce boxes", providerName: "Campus Community Pantry", providerType: .pantry, description: "Mixed apples, greens, potatoes, and shelf-stable staples packed for student pickup.", pickupWindow: "Today, 2:00-5:00 PM", distanceInMiles: 0.8, quantityDescription: "12 boxes available", dietaryTags: [.vegetarian, .vegan, .glutenFree], coordinate: CLLocationCoordinate2D(latitude: 40.7312, longitude: -73.9912), postedAt: Date(), imageURL: URL(string: "https://images.unsplash.com/photo-1542838132-92c53300491e?w=800")),
            FoodOffering(id: UUID(), title: "Catered rice bowls", providerName: "Union Events Team", providerType: .campus, description: "Leftover individually packed rice bowls from a student org lunch.", pickupWindow: "Today, 1:15-2:15 PM", distanceInMiles: 1.1, quantityDescription: "18 bowls", dietaryTags: [.vegetarian, .halal], coordinate: CLLocationCoordinate2D(latitude: 40.7277, longitude: -73.9951), postedAt: Date(), imageURL: URL(string: "https://images.unsplash.com/photo-1512058564366-18510be2db19?w=800")),
            FoodOffering(id: UUID(), title: "Cafe sandwiches", providerName: "Northside Market", providerType: .business, description: "Wrapped sandwiches nearing end-of-day freshness, labeled with ingredients.", pickupWindow: "Tomorrow, 9:00-10:30 AM", distanceInMiles: 2.3, quantityDescription: "30 sandwiches", dietaryTags: [.kosher], coordinate: CLLocationCoordinate2D(latitude: 40.7362, longitude: -73.9890), postedAt: Date(), imageURL: URL(string: "https://images.unsplash.com/photo-1553909489-cd47e0907980?w=800"))
        ]
    }
}

struct SupabaseFoodOfferingService: FoodOfferingServicing {
    private let client: FullrSupabaseClient?

    init(client: FullrSupabaseClient? = SupabaseClientProvider.makeClient()) {
        self.client = client
    }

    func fetchOfferings(filter: OfferingFilter) async throws -> [FoodOffering] {
        guard let client else { throw AuthenticationError.missingSupabaseConfiguration }
        let offers = try await client.fetchOffers().filter(\.isAvailable)
        let stores = try await client.fetchStores()
        let storesByID = Dictionary(uniqueKeysWithValues: stores.map { ($0.id, $0) })

        var offerings: [FoodOffering] = []
        for offer in offers {
            guard let store = storesByID[offer.storeID],
                  let coordinate = store.addressCoordinate else {
                continue
            }

            let offering = offer.foodOffering(store: store, coordinate: coordinate, userCoordinate: filter.userCoordinate)
            if matches(offering, filter: filter) {
                offerings.append(offering)
            }
        }

        return offerings.sorted { $0.distanceInMiles < $1.distanceInMiles }
    }

    private func matches(_ offering: FoodOffering, filter: OfferingFilter) -> Bool {
        let matchesSearch = filter.searchText.isEmpty
            || offering.title.localizedStandardContains(filter.searchText)
            || offering.providerName.localizedStandardContains(filter.searchText)
            || offering.description.localizedStandardContains(filter.searchText)
        let matchesProvider = filter.providerType == nil || offering.providerType == filter.providerType
        let matchesDistance = filter.userCoordinate == nil || offering.distanceInMiles <= filter.maximumDistanceInMiles
        let matchesDietary = filter.selectedDietaryTags.isEmpty || filter.selectedDietaryTags.isSubset(of: Set(offering.dietaryTags))
        return matchesSearch && matchesProvider && matchesDistance && matchesDietary
    }
}

private extension SupabaseStore {
    var addressCoordinate: CLLocationCoordinate2D? {
        guard let values = address.coordinatePair else { return nil }

        let first = values.first
        let second = values.second

        if first.isLatitude, second.isLongitude {
            return CLLocationCoordinate2D(latitude: first, longitude: second)
        }

        if first.isLongitude, second.isLatitude {
            return CLLocationCoordinate2D(latitude: second, longitude: first)
        }

        return nil
    }
}

private extension String {
    var coordinatePair: (first: Double, second: Double)? {
        let pattern = #"(-?\d+(?:\.\d+)?)\s*°?\s*([NSEWnsew])?"#
        guard let regex = try? Regex(pattern) else { return nil }

        let matches = matches(of: regex).prefix(2).compactMap { match -> Double? in
            guard var value = Double(String(match.output[1].substring ?? "")) else { return nil }
            if let direction = match.output[2].substring?.lowercased() {
                switch direction {
                case "s", "w":
                    value = -abs(value)
                case "n", "e":
                    value = abs(value)
                default:
                    break
                }
            }
            return value
        }

        guard matches.count == 2 else { return nil }
        return (matches[0], matches[1])
    }
}

private extension Double {
    var isLatitude: Bool { (-90...90).contains(self) }
    var isLongitude: Bool { (-180...180).contains(self) }
}
