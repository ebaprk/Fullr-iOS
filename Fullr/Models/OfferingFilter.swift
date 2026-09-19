import Foundation
import CoreLocation

struct OfferingFilter: Equatable {
    var searchText = ""
    var providerType: ProviderType?
    var selectedDietaryTags: Set<DietaryTag> = []
    var maximumDistanceInMiles = 5.0
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
