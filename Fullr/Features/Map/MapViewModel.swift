import Foundation
import CoreLocation
import MapKit
import Observation
import SwiftUI

@Observable
final class MapViewModel: NSObject, CLLocationManagerDelegate {
    @ObservationIgnored private let locationManager = CLLocationManager()
    private let offeringService: FoodOfferingServicing

    var offerings: [FoodOffering] = []
    var selectedOffering: FoodOffering?
    var isLoading = false
    var cameraPosition: MapCameraPosition

    private let defaultRegion = MKCoordinateRegion(
        center: CLLocationCoordinate2D(latitude: 40.7306, longitude: -73.9950),
        span: MKCoordinateSpan(latitudeDelta: 0.04, longitudeDelta: 0.04)
    )
    private let userLocationSpan = MKCoordinateSpan(latitudeDelta: 0.02, longitudeDelta: 0.02)

    init(offeringService: FoodOfferingServicing) {
        self.offeringService = offeringService
        self.cameraPosition = .region(defaultRegion)
        super.init()
        locationManager.delegate = self
        locationManager.desiredAccuracy = kCLLocationAccuracyHundredMeters
    }

    func loadOfferings() async {
        isLoading = true
        defer { isLoading = false }
        do {
            offerings = try await offeringService.fetchOfferings(filter: OfferingFilter())
            selectedOffering = offerings.first
        } catch {
            offerings = []
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
        cameraPosition = .region(MKCoordinateRegion(center: coordinate, span: userLocationSpan))
        manager.stopUpdatingLocation()
    }
}
