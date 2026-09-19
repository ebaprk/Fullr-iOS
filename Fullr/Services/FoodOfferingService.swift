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
            FoodOffering(id: UUID(), title: "Fresh bagels and spreads", providerName: "Main Street Bagels", providerType: .restaurant, description: "Assorted plain, sesame, and everything bagels with sealed cream cheese tubs.", pickupWindow: "Today, 4:30-6:00 PM", distanceInMiles: 0.4, quantityDescription: "About 24 servings", dietaryTags: [.vegetarian], coordinate: CLLocationCoordinate2D(latitude: 40.7295, longitude: -73.9965), postedAt: Date()),
            FoodOffering(id: UUID(), title: "Pantry produce boxes", providerName: "Campus Community Pantry", providerType: .pantry, description: "Mixed apples, greens, potatoes, and shelf-stable staples packed for student pickup.", pickupWindow: "Today, 2:00-5:00 PM", distanceInMiles: 0.8, quantityDescription: "12 boxes available", dietaryTags: [.vegetarian, .vegan, .glutenFree], coordinate: CLLocationCoordinate2D(latitude: 40.7312, longitude: -73.9912), postedAt: Date()),
            FoodOffering(id: UUID(), title: "Catered rice bowls", providerName: "Union Events Team", providerType: .campus, description: "Leftover individually packed rice bowls from a student org lunch.", pickupWindow: "Today, 1:15-2:15 PM", distanceInMiles: 1.1, quantityDescription: "18 bowls", dietaryTags: [.vegetarian, .halal], coordinate: CLLocationCoordinate2D(latitude: 40.7277, longitude: -73.9951), postedAt: Date()),
            FoodOffering(id: UUID(), title: "Cafe sandwiches", providerName: "Northside Market", providerType: .business, description: "Wrapped sandwiches nearing end-of-day freshness, labeled with ingredients.", pickupWindow: "Tomorrow, 9:00-10:30 AM", distanceInMiles: 2.3, quantityDescription: "30 sandwiches", dietaryTags: [.kosher], coordinate: CLLocationCoordinate2D(latitude: 40.7362, longitude: -73.9890), postedAt: Date())
        ]
    }
}

struct SupabaseFoodOfferingService: FoodOfferingServicing {
    func fetchOfferings(filter: OfferingFilter) async throws -> [FoodOffering] {
        try await MockFoodOfferingService().fetchOfferings(filter: filter)
    }
}
