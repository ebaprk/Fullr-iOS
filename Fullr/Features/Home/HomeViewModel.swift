import Foundation
import Observation

@Observable
@MainActor
final class HomeViewModel {
    private let offeringService: FoodOfferingServicing
    private var filterTask: Task<Void, Never>?
    private var loadGeneration = 0

    var offerings: [FoodOffering] = []
    var filter = OfferingFilter()
    var isLoading = false
    var errorMessage: String?

    init(offeringService: FoodOfferingServicing) {
        self.offeringService = offeringService
    }

    func loadOfferings() async {
        filterTask?.cancel()
        await fetchOfferings()
    }

    func scheduleLoadOfferings() {
        filterTask?.cancel()
        filterTask = Task { [weak self] in
            try? await Task.sleep(for: .milliseconds(350))
            guard !Task.isCancelled else { return }
            await self?.fetchOfferings()
        }
    }

    private func fetchOfferings() async {
        loadGeneration += 1
        let generation = loadGeneration
        let activeFilter = filter
        isLoading = true
        errorMessage = nil
        do {
            let fetchedOfferings = try await offeringService.fetchOfferings(filter: activeFilter)
            guard generation == loadGeneration else { return }
            offerings = fetchedOfferings
        } catch {
            guard generation == loadGeneration else { return }
            offerings = []
            errorMessage = error.localizedDescription
        }
        if generation == loadGeneration {
            isLoading = false
        }
    }

    func updateProviderType(_ providerType: ProviderType?) async {
        filter.providerType = providerType
        await loadOfferings()
    }

    func updateDistance(_ distance: Double) async {
        filter.maximumDistanceInMiles = distance
        scheduleLoadOfferings()
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
