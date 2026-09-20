import Foundation
import MapKit

struct FoodOffering: Identifiable, Hashable {
    let id: UUID
    let title: String
    let providerName: String
    let providerType: ProviderType
    let description: String
    let pickupWindow: String
    let distanceInMiles: Double
    let quantityDescription: String
    let price: Double
    let dietaryTags: [DietaryTag]
    let coordinate: CLLocationCoordinate2D
    let postedAt: Date
    let imageURL: URL?
    var isStudentVerifiedProvider = true
    var providerID: UUID? = nil
    var providerDescription = ""
    var providerAddress = ""
    var hasPickupCoordinate = true

    static func == (lhs: FoodOffering, rhs: FoodOffering) -> Bool { lhs.id == rhs.id }

    func hash(into hasher: inout Hasher) { hasher.combine(id) }

    func isFromSameProvider(as offering: FoodOffering) -> Bool {
        if let providerID, let otherID = offering.providerID {
            return providerID == otherID
        }
        // Older/sample records may not have a store ID. Keep branches separate.
        return providerName == offering.providerName
            && providerType == offering.providerType
            && coordinate.latitude == offering.coordinate.latitude
            && coordinate.longitude == offering.coordinate.longitude
    }

    var priceText: String {
        guard price > 0 else { return "Free" }
        return price.formatted(.currency(code: "USD"))
    }
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
