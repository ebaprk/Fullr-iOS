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

            VStack(spacing: 0) {
                distanceFilter
                    .padding(.horizontal, 16)
                    .padding(.top, 12)

                Spacer()
            }

            if !viewModel.nearbyOfferings.isEmpty {
                ScrollView(.horizontal) {
                    HStack(spacing: 12) {
                        ForEach(viewModel.nearbyOfferings) { offering in
                            Button {
                                viewModel.selectOffering(offering)
                            } label: {
                                FoodOfferingCard(offering: offering)
                                    .frame(width: 320)
                            }
                            .buttonStyle(.plain)
                        }
                    }
                    .padding(.horizontal, 16)
                    .padding(.vertical, 12)
                }
                .scrollIndicators(.hidden)
                .background(.regularMaterial)
            }
        }
        .navigationTitle("Map")
        .toolbar { if viewModel.isLoading { ProgressView() } }
        .task {
            viewModel.requestLocationIfNeeded()
            await viewModel.pollOfferings()
        }
    }

    private var distanceFilter: some View {
        Picker("Distance", selection: distanceBinding) {
            ForEach(OfferingFilter.distanceOptionsInMiles, id: \.self) { distance in
                Text("\(Int(distance)) mi").tag(distance)
            }
        }
        .pickerStyle(.segmented)
        .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 8))
    }

    private var distanceBinding: Binding<Double> {
        Binding(
            get: { viewModel.maximumDistanceInMiles },
            set: { newValue in Task { await viewModel.updateDistance(newValue) } }
        )
    }
}

#Preview {
    NavigationStack {
        MapScreenView(viewModel: MapViewModel(offeringService: MockFoodOfferingService()))
    }
}
