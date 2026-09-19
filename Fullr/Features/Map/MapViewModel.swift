import Foundation
import MapKit
import Observation

@Observable
final class MapViewModel {
    private let offeringService: FoodOfferingServicing

    var offerings: [FoodOffering] = []
    var selectedOffering: FoodOffering?
    var isLoading = false

    let region = MKCoordinateRegion(center: CLLocationCoordinate2D(latitude: 40.7306, longitude: -73.9950), span: MKCoordinateSpan(latitudeDelta: 0.04, longitudeDelta: 0.04))

    init(offeringService: FoodOfferingServicing) {
        self.offeringService = offeringService
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
}
