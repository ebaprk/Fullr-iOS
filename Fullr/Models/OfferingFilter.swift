import Foundation
import CoreLocation

struct OfferingFilter: Equatable {
    static let defaultMaximumDistanceInMiles = 5.0
    static let distanceOptionsInMiles = [1.0, 5.0, 10.0, 25.0]

    var searchText = ""
    var providerType: ProviderType?
    var selectedDietaryTags: Set<DietaryTag> = []
    var maximumDistanceInMiles = defaultMaximumDistanceInMiles
    var userCoordinate: CLLocationCoordinate2D?

    static func == (lhs: OfferingFilter, rhs: OfferingFilter) -> Bool {
        lhs.searchText == rhs.searchText
            && lhs.providerType == rhs.providerType
            && lhs.selectedDietaryTags == rhs.selectedDietaryTags
            && lhs.maximumDistanceInMiles == rhs.maximumDistanceInMiles
            && lhs.userCoordinate?.latitude == rhs.userCoordinate?.latitude
            && lhs.userCoordinate?.longitude == rhs.userCoordinate?.longitude
    }
}
