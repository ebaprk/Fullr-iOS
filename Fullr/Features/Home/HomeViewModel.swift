import Foundation
import Observation

@Observable
final class HomeViewModel {
    private let offeringService: FoodOfferingServicing

    var offerings: [FoodOffering] = []
    var filter = OfferingFilter()
    var isLoading = false
    var errorMessage: String?

    init(offeringService: FoodOfferingServicing) {
        self.offeringService = offeringService
    }

    func loadOfferings() async {
        isLoading = true
        errorMessage = nil
        do { offerings = try await offeringService.fetchOfferings(filter: filter) } catch { errorMessage = error.localizedDescription }
        isLoading = false
    }

    func updateProviderType(_ providerType: ProviderType?) async {
        filter.providerType = providerType
        await loadOfferings()
    }

    func updateDistance(_ distance: Double) async {
        filter.maximumDistanceInMiles = distance
        await loadOfferings()
    }

    func toggleDietaryTag(_ tag: DietaryTag) async {
        if filter.selectedDietaryTags.contains(tag) {
            filter.selectedDietaryTags.remove(tag)
        } else {
            filter.selectedDietaryTags.insert(tag)
        }
        await loadOfferings()
    }
}
