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
                        .tint(FullrPalette.gold)
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
        HStack(spacing: 0) {
            ForEach(OfferingFilter.distanceOptionsInMiles, id: \.self) { distance in
                Button {
                    Task { await viewModel.updateDistance(distance) }
                } label: {
                    Text("\(Int(distance)) mi")
                        .font(.subheadline.weight(.bold))
                        .frame(maxWidth: .infinity)
                        .frame(height: 40)
                        .background(distance == viewModel.maximumDistanceInMiles ? FullrPalette.cream : FullrPalette.moss, in: Capsule())
                        .foregroundStyle(distance == viewModel.maximumDistanceInMiles ? FullrPalette.pine : FullrPalette.cream)
                }
                .buttonStyle(.plain)
            }
        }
        .padding(4)
        .background(FullrPalette.olive, in: Capsule())
    }
}

#Preview {
    NavigationStack {
        MapScreenView(viewModel: MapViewModel(offeringService: MockFoodOfferingService()))
    }
}
