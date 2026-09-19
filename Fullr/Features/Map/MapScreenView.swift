import MapKit
import SwiftUI

struct MapScreenView: View {
    @State var viewModel: MapViewModel

    var body: some View {
        ZStack(alignment: .bottom) {
            Map(position: $viewModel.cameraPosition) {
                UserAnnotation()

                ForEach(viewModel.offerings) { offering in
                    Marker(offering.title, systemImage: offering.providerType.systemImageName, coordinate: offering.coordinate)
                        .tint(.green)
                }
            }
            .ignoresSafeArea(edges: .bottom)

            if let selectedOffering = viewModel.selectedOffering {
                FoodOfferingCard(offering: selectedOffering)
                    .padding()
                    .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 8))
                    .padding()
            }
        }
        .navigationTitle("Map")
        .toolbar { if viewModel.isLoading { ProgressView() } }
        .task {
            viewModel.requestLocationIfNeeded()
            await viewModel.loadOfferings()
        }
    }
}

#Preview {
    NavigationStack {
        MapScreenView(viewModel: MapViewModel(offeringService: MockFoodOfferingService()))
    }
}
