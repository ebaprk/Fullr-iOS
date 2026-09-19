import Foundation
import MapKit

struct FoodOffering: Identifiable, Equatable {
    let id: UUID
    let title: String
    let providerName: String
    let providerType: ProviderType
    let description: String
    let pickupWindow: String
    let distanceInMiles: Double
    let quantityDescription: String
    let dietaryTags: [DietaryTag]
    let coordinate: CLLocationCoordinate2D
    let postedAt: Date
    let imageURL: URL?

    static func == (lhs: FoodOffering, rhs: FoodOffering) -> Bool { lhs.id == rhs.id }
}

enum ProviderType: String, CaseIterable, Identifiable {
    case restaurant, pantry, business, campus
    var id: String { rawValue }

    var displayName: String {
        switch self {
        case .restaurant: "Restaurant"
        case .pantry: "Pantry"
        case .business: "Business"
        case .campus: "Campus"
        }
    }

    var systemImageName: String {
        switch self {
        case .restaurant: "fork.knife"
        case .pantry: "shippingbox"
        case .business: "building.2"
        case .campus: "graduationcap"
        }
    }
}

enum DietaryTag: String, CaseIterable, Identifiable {
    case vegetarian, vegan, glutenFree, halal, kosher
    var id: String { rawValue }

    var displayName: String {
        switch self {
        case .vegetarian: "Vegetarian"
        case .vegan: "Vegan"
        case .glutenFree: "Gluten-free"
        case .halal: "Halal"
        case .kosher: "Kosher"
        }
    }
}
