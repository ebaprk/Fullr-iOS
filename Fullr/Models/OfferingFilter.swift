import Foundation

struct OfferingFilter: Equatable {
    var searchText = ""
    var providerType: ProviderType?
    var selectedDietaryTags: Set<DietaryTag> = []
    var maximumDistanceInMiles = 5.0
}
