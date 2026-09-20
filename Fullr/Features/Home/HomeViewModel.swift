import Foundation
import CoreLocation
import Observation

@Observable
final class HomeViewModel: NSObject, CLLocationManagerDelegate {
    @ObservationIgnored private let locationManager = CLLocationManager()
    let offeringService: FoodOfferingServicing
    private var filterTask: Task<Void, Never>?
    private var loadGeneration = 0

    var offerings: [FoodOffering] = []
    var filter = OfferingFilter()
    var isLoading = false
    var errorMessage: String?

    init(offeringService: FoodOfferingServicing) {
        self.offeringService = offeringService
        super.init()
        locationManager.delegate = self
        locationManager.desiredAccuracy = kCLLocationAccuracyHundredMeters
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

    func requestLocationIfNeeded() {
        switch locationManager.authorizationStatus {
        case .notDetermined:
            locationManager.requestWhenInUseAuthorization()
        case .authorizedAlways, .authorizedWhenInUse:
            if let coordinate = locationManager.location?.coordinate {
                filter.userCoordinate = coordinate
            }
            locationManager.startUpdatingLocation()
        case .denied, .restricted:
            break
        @unknown default:
            break
        }
    }

    func locationManagerDidChangeAuthorization(_ manager: CLLocationManager) {
        switch manager.authorizationStatus {
        case .authorizedAlways, .authorizedWhenInUse:
            manager.startUpdatingLocation()
        case .denied, .notDetermined, .restricted:
            break
        @unknown default:
            break
        }
    }

    func locationManager(_ manager: CLLocationManager, didUpdateLocations locations: [CLLocation]) {
        guard let coordinate = locations.last?.coordinate else { return }
        filter.userCoordinate = coordinate
        manager.stopUpdatingLocation()
        Task { await loadOfferings() }
    }

    func updateProviderType(_ providerType: ProviderType?) async {
        filter.providerType = providerType
        await loadOfferings()
    }

    func updateDistance(_ distance: Double) async {
        filter.maximumDistanceInMiles = distance
        scheduleLoadOfferings()
    }

    func updateStudentVerifiedProviders(_ showOnlyVerifiedProviders: Bool) async {
        guard filter.showOnlyStudentVerifiedProviders != showOnlyVerifiedProviders else { return }
        filter.showOnlyStudentVerifiedProviders = showOnlyVerifiedProviders
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
