import Foundation
import CoreLocation
import Observation

@Observable
final class HomeViewModel: NSObject, CLLocationManagerDelegate {
    @ObservationIgnored private let locationManager = CLLocationManager()
    private let offeringService: FoodOfferingServicing

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
        isLoading = true
        errorMessage = nil
        do { offerings = try await offeringService.fetchOfferings(filter: filter) } catch { errorMessage = error.localizedDescription }
        isLoading = false
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
