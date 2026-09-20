import Foundation
import CoreLocation
import MapKit
import Observation
import SwiftUI

@Observable
final class MapViewModel: NSObject, CLLocationManagerDelegate {
    @ObservationIgnored private let locationManager = CLLocationManager()
    let offeringService: FoodOfferingServicing

    var offerings: [FoodOffering] = []
    var selectedOffering: FoodOffering?
    var isLoading = false
    var cameraPosition: MapCameraPosition
    var maximumDistanceInMiles = OfferingFilter.defaultMaximumDistanceInMiles
    var showOnlyStudentVerifiedProviders = false
    private var userCoordinate: CLLocationCoordinate2D?
    private var loadGeneration = 0

    private let defaultRegion = MKCoordinateRegion(
        center: CLLocationCoordinate2D(latitude: 40.7306, longitude: -73.9950),
        span: MKCoordinateSpan(latitudeDelta: 0.04, longitudeDelta: 0.04)
    )
    private let userLocationSpan = MKCoordinateSpan(latitudeDelta: 0.02, longitudeDelta: 0.02)
    private let offeringSpan = MKCoordinateSpan(latitudeDelta: 0.01, longitudeDelta: 0.01)

    var nearbyOfferings: [FoodOffering] {
        Array(offerings.prefix(5))
    }

    init(offeringService: FoodOfferingServicing) {
        self.offeringService = offeringService
        self.cameraPosition = .region(defaultRegion)
        super.init()
        locationManager.delegate = self
        locationManager.desiredAccuracy = kCLLocationAccuracyHundredMeters
    }

    func loadOfferings() async {
        loadGeneration += 1
        let generation = loadGeneration
        isLoading = true
        defer {
            if generation == loadGeneration { isLoading = false }
        }
        do {
            let fetchedOfferings = try await offeringService.fetchOfferings(filter: OfferingFilter(showOnlyStudentVerifiedProviders: showOnlyStudentVerifiedProviders, maximumDistanceInMiles: maximumDistanceInMiles, userCoordinate: userCoordinate))
            // Location may arrive while addresses are being geocoded. Only the
            // latest fetch can publish distances/filter results for the map.
            guard generation == loadGeneration else { return }
            offerings = fetchedOfferings
            if let selectedOffering, offerings.contains(selectedOffering) {
                self.selectedOffering = selectedOffering
            } else {
                selectedOffering = offerings.first
            }
        } catch {
            guard generation == loadGeneration else { return }
            offerings = []
        }
    }

    func pollOfferings() async {
        await loadOfferings()

        while !Task.isCancelled {
            do {
                try await Task.sleep(for: .seconds(30))
            } catch {
                break
            }
            await loadOfferings()
        }
    }

    func requestLocationIfNeeded() {
        switch locationManager.authorizationStatus {
        case .notDetermined:
            locationManager.requestWhenInUseAuthorization()
        case .authorizedAlways, .authorizedWhenInUse:
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
        userCoordinate = coordinate
        cameraPosition = .region(MKCoordinateRegion(center: coordinate, span: userLocationSpan))
        manager.stopUpdatingLocation()
        Task { await loadOfferings() }
    }

    func selectOffering(_ offering: FoodOffering) {
        selectedOffering = offering
        cameraPosition = .region(MKCoordinateRegion(center: offering.coordinate, span: offeringSpan))
    }

    func updateDistance(_ distance: Double) async {
        maximumDistanceInMiles = distance
        await loadOfferings()
    }

    func updateStudentVerifiedProviders(_ showOnlyVerifiedProviders: Bool) async {
        guard showOnlyStudentVerifiedProviders != showOnlyVerifiedProviders else { return }
        showOnlyStudentVerifiedProviders = showOnlyVerifiedProviders
        await loadOfferings()
    }
}
