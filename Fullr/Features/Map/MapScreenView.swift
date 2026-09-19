import MapKit
import SwiftUI

struct MapScreenView: View {
    @State var viewModel: MapViewModel
    @State private var detailOffering: FoodOffering?

    var body: some View {
        VStack(spacing: 0) {
            VStack(alignment: .leading, spacing: 18) {
                HStack(alignment: .center) {
                    VStack(alignment: .leading, spacing: 4) {
                        Text("Good food, mapped.")
                            .font(FullrFont.semibold(30, relativeTo: .largeTitle))
                            .tracking(-1)
                        Text("Find your next local pickup.")
                            .font(FullrFont.regular(14, relativeTo: .subheadline))
                            .foregroundStyle(FullrPalette.moss)
                    }
                    Spacer(minLength: 8)
                    if viewModel.isLoading {
                        ProgressView().tint(FullrPalette.moss)
                    }
                }

                FullrDistancePicker(selectedDistance: viewModel.maximumDistanceInMiles) { distance in
                    Task { await viewModel.updateDistance(distance) }
                }
            }
            .frame(maxWidth: 680)
            .padding(.horizontal, 24)
            .padding(.top, 22)
            .padding(.bottom, 20)
            .frame(maxWidth: .infinity)
            .background(FullrPalette.cream)

            Map(position: $viewModel.cameraPosition) {
                UserAnnotation()
                ForEach(viewModel.offerings) { offering in
                    Annotation(offering.providerName, coordinate: offering.coordinate) {
                        Button { openOffering(offering) } label: {
                            Image(systemName: offering.providerType.systemImageName)
                                .font(FullrFont.medium(17))
                                .frame(width: 44, height: 44)
                                .foregroundStyle(FullrPalette.cream)
                                .background(FullrPalette.moss, in: RoundedRectangle(cornerRadius: 16))
                                .overlay { RoundedRectangle(cornerRadius: 16).strokeBorder(FullrPalette.cream, lineWidth: 3) }
                        }
                        .buttonStyle(FullrPressStyle())
                        .accessibilityLabel("\(offering.title) at \(offering.providerName)")
                    }
                }
            }
            .mapStyle(.standard(elevation: .flat, pointsOfInterest: .excludingAll))
            .mapControls { MapCompass() }
            .clipShape(RoundedRectangle(cornerRadius: 28))
            .frame(maxWidth: 680)
            .padding(.horizontal, 24)
            .frame(maxWidth: .infinity)
            .safeAreaInset(edge: .bottom, spacing: 0) {
                if !viewModel.nearbyOfferings.isEmpty {
                    ScrollView(.horizontal) {
                        HStack(alignment: .top, spacing: 12) {
                            ForEach(viewModel.nearbyOfferings) { offering in
                                Button { openOffering(offering) } label: {
                                    FoodOfferingCard(offering: offering, isCompact: true)
                                        .frame(width: 300)
                                }
                                .buttonStyle(FullrPressStyle())
                                .accessibilityHint("Opens offer details")
                            }
                        }
                        .scrollTargetLayout()
                        .padding(.horizontal, 24)
                        .padding(.vertical, 14)
                    }
                    .scrollTargetBehavior(.viewAligned)
                    .scrollIndicators(.hidden)
                    .fixedSize(horizontal: false, vertical: true)
                    .frame(maxWidth: 728)
                    .frame(maxWidth: .infinity)
                    .background(FullrPalette.cream)
                }
            }
        }
        .background(FullrPalette.cream)
        .foregroundStyle(FullrPalette.pine)
        .toolbar(.hidden, for: .navigationBar)
        .navigationDestination(item: $detailOffering) { offering in
            OfferingDetailView(offering: offering, offeringService: viewModel.offeringService)
        }
        .task {
            viewModel.requestLocationIfNeeded()
            await viewModel.pollOfferings()
        }
    }

    private func openOffering(_ offering: FoodOffering) {
        viewModel.selectOffering(offering)
        detailOffering = offering
    }
}

#Preview {
    NavigationStack {
        MapScreenView(viewModel: MapViewModel(offeringService: MockFoodOfferingService()))
    }
}
