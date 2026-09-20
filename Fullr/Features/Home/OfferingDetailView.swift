import MapKit
import SwiftUI

struct OfferingDetailView: View {
    let offering: FoodOffering
    let offeringService: FoodOfferingServicing
    @State private var didIncrementView = false

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 26) {
                OfferingImage(offering: offering)
                    .frame(height: 220)
                    .clipShape(RoundedRectangle(cornerRadius: 28))
                    .accessibilityHidden(true)

                VStack(alignment: .leading, spacing: 10) {
                    Label(offering.providerType.displayName, systemImage: offering.providerType.systemImageName)
                        .font(FullrFont.medium(13, relativeTo: .caption))
                        .foregroundStyle(FullrPalette.moss)
                    Text(offering.title)
                        .font(FullrFont.semibold(32, relativeTo: .largeTitle))
                        .tracking(-0.8)
                        .fixedSize(horizontal: false, vertical: true)
                        .accessibilityAddTraits(.isHeader)
                    DietaryTagRow(tags: offering.dietaryTags)
                }

                OfferClaimSection(offerID: offering.id, service: offeringService)
                    .id(offering.id)

                NavigationLink {
                    ProviderDetailView(offering: offering, offeringService: offeringService)
                } label: {
                    HStack(spacing: 14) {
                        Image(systemName: offering.providerType.systemImageName)
                            .font(FullrFont.medium(21))
                            .frame(width: 48, height: 48)
                            .foregroundStyle(FullrPalette.cream)
                            .background(FullrPalette.moss, in: RoundedRectangle(cornerRadius: 16))
                        VStack(alignment: .leading, spacing: 4) {
                            Text(offering.providerName)
                                .font(FullrFont.semibold(17))
                            Text("View provider & available offers")
                                .font(FullrFont.regular(12, relativeTo: .caption))
                                .foregroundStyle(FullrPalette.moss)
                        }
                        Spacer(minLength: 0)
                        Image(systemName: "chevron.right")
                            .font(FullrFont.medium(13))
                    }
                    .foregroundStyle(FullrPalette.pine)
                    .padding(16)
                    .overlay { RoundedRectangle(cornerRadius: 22).strokeBorder(FullrPalette.olive, lineWidth: 1) }
                    .contentShape(RoundedRectangle(cornerRadius: 22))
                }
                .buttonStyle(FullrPressStyle())
                .accessibilityHint("Opens \(offering.providerName)")

                VStack(alignment: .leading, spacing: 18) {
                    DetailSectionTitle(title: "The details")
                    DetailInfoRow(title: "Price", value: offering.priceText, systemImage: "tag")
                    DetailInfoRow(title: "Pickup window", value: offering.pickupWindow, systemImage: "clock")
                    if !offering.quantityDescription.isEmpty {
                        DetailInfoRow(
                            title: offering.quantityDescription.hasSuffix("views") ? "Offer activity" : "Available",
                            value: offering.quantityDescription,
                            systemImage: offering.quantityDescription.hasSuffix("views") ? "eye" : "basket"
                        )
                    }
                    if offering.distanceInMiles > 0 {
                        DetailInfoRow(title: "Distance", value: offering.badgeText, systemImage: "location")
                    }
                }

                if !offering.description.isEmpty {
                    VStack(alignment: .leading, spacing: 10) {
                        DetailSectionTitle(title: "About this offer")
                        Text(offering.description)
                            .font(FullrFont.regular(16))
                            .foregroundStyle(FullrPalette.moss)
                            .fixedSize(horizontal: false, vertical: true)
                            .textSelection(.enabled)
                    }
                }

                PickupLocationSection(offering: offering)
            }
            .frame(maxWidth: 680, alignment: .leading)
            .padding(.horizontal, 24)
            .padding(.vertical, 20)
            .frame(maxWidth: .infinity)
        }
        .modifier(DetailPageStyle(title: "Offer details"))
        .task(id: offering.id) {
            await incrementViewCountIfNeeded()
        }
    }

    private func incrementViewCountIfNeeded() async {
        guard !didIncrementView else { return }
        didIncrementView = true
        try? await offeringService.incrementViews(for: offering.id)
    }
}

private struct OfferClaimSection: View {
    @State private var viewModel: OfferClaimViewModel

    init(offerID: UUID, service: FoodOfferingServicing) {
        _viewModel = State(initialValue: OfferClaimViewModel(offerID: offerID, service: service))
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            if viewModel.isLoading {
                ProgressView("Checking your claim…")
                    .tint(FullrPalette.moss)
            } else if viewModel.hasLoaded {
                HStack(alignment: .top, spacing: 12) {
                    Image(systemName: viewModel.claimed == true ? "checkmark.circle.fill" : "circle.dashed")
                        .font(FullrFont.medium(28))
                        .foregroundStyle(FullrPalette.moss)
                        .accessibilityHidden(true)
                    VStack(alignment: .leading, spacing: 6) {
                        Text(viewModel.claimed == true ? "Claimed by you" : "Not claimed yet")
                            .font(FullrFont.semibold(21, relativeTo: .title3))
                            .accessibilityAddTraits(.isHeader)
                        Text(viewModel.claimed == true
                             ? "You can find this offer in You → Claimed offers."
                             : "Already claimed this offer? Confirm below to add it to your claimed offers.")
                            .font(FullrFont.regular(14))
                            .foregroundStyle(FullrPalette.moss)
                    }
                }

                if viewModel.isSaving {
                    ProgressView(viewModel.claimed == true ? "Removing your claim…" : "Confirming your claim…")
                        .tint(FullrPalette.moss)
                        .frame(maxWidth: .infinity, minHeight: 48)
                } else if viewModel.claimed == true {
                    Button { Task { await viewModel.save(false) } } label: {
                        Label("Undo claim", systemImage: "arrow.uturn.backward")
                            .font(FullrFont.medium(15))
                            .frame(maxWidth: .infinity, minHeight: 48)
                            .overlay { Capsule().strokeBorder(FullrPalette.moss, lineWidth: 1) }
                    }
                    .foregroundStyle(FullrPalette.moss)
                    .buttonStyle(FullrPressStyle())
                    .accessibilityHint("Removes this offer from your claimed offers")
                } else {
                    Button { Task { await viewModel.save(true) } } label: {
                        Label("Confirm I claimed this", systemImage: "checkmark.circle")
                    }
                    .buttonStyle(FullrPrimaryButtonStyle())
                    .accessibilityHint("Saves your claim and adds this offer to your claimed offers")
                }
            }

            if let errorMessage = viewModel.errorMessage {
                Label(errorMessage, systemImage: "exclamationmark.circle")
                    .font(FullrFont.regular(14))
                    .foregroundStyle(FullrPalette.moss)
                if !viewModel.hasLoaded {
                    Button("Try again") { Task { await viewModel.load() } }
                        .buttonStyle(FullrPrimaryButtonStyle())
                }
            }
        }
        .padding(20)
        .frame(maxWidth: .infinity, alignment: .leading)
        .overlay { RoundedRectangle(cornerRadius: 24).strokeBorder(FullrPalette.moss, lineWidth: 1) }
        .task { await viewModel.load() }
    }
}

struct ProviderDetailView: View {
    let offering: FoodOffering
    let offeringService: FoodOfferingServicing
    @State private var offerings: [FoodOffering] = []
    @State private var isLoading = true
    @State private var errorMessage: String?

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 26) {
                OfferingImage(offering: offering)
                    .frame(height: 200)
                    .clipShape(RoundedRectangle(cornerRadius: 28))
                    .accessibilityHidden(true)

                VStack(alignment: .leading, spacing: 10) {
                    Label(offering.providerType.displayName, systemImage: offering.providerType.systemImageName)
                        .font(FullrFont.medium(13, relativeTo: .caption))
                        .foregroundStyle(FullrPalette.moss)
                    Text(offering.providerName)
                        .font(FullrFont.semibold(32, relativeTo: .largeTitle))
                        .tracking(-0.8)
                        .fixedSize(horizontal: false, vertical: true)
                        .accessibilityAddTraits(.isHeader)
                    if !offering.providerDescription.isEmpty {
                        Text(offering.providerDescription)
                            .font(FullrFont.regular(16))
                            .foregroundStyle(FullrPalette.moss)
                            .fixedSize(horizontal: false, vertical: true)
                    }
                }

                VStack(alignment: .leading, spacing: 16) {
                    DetailSectionTitle(title: "Available offers")
                    providerOfferings
                }
                PickupLocationSection(offering: offering)
            }
            .frame(maxWidth: 680, alignment: .leading)
            .padding(.horizontal, 24)
            .padding(.vertical, 20)
            .frame(maxWidth: .infinity)
        }
        .modifier(DetailPageStyle(title: offering.providerType.displayName))
        .task { await loadOfferings() }
        .refreshable { await loadOfferings() }
    }

    @ViewBuilder
    private var providerOfferings: some View {
        if isLoading {
            ProgressView("Checking available offers…")
                .tint(FullrPalette.moss)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 20)
        } else if let errorMessage {
            VStack(alignment: .leading, spacing: 12) {
                Text(errorMessage)
                    .foregroundStyle(FullrPalette.moss)
                Button("Try again") { Task { await loadOfferings() } }
                    .buttonStyle(FullrPrimaryButtonStyle())
            }
        } else if offerings.isEmpty {
            FullrEmptyState(title: "More good food soon", message: "There are no available offers from this provider right now.", systemImage: "basket")
        } else {
            ForEach(offerings) { providerOffering in
                NavigationLink {
                    OfferingDetailView(offering: providerOffering, offeringService: offeringService)
                } label: {
                    FoodOfferingCard(offering: providerOffering, isCompact: true)
                }
                .buttonStyle(FullrPressStyle())
                .accessibilityHint("Opens offer details")
            }
        }
    }

    private func loadOfferings() async {
        isLoading = true
        errorMessage = nil
        do {
            // Provider pages include all of the provider's offers, independently
            // of the search, dietary, or distance filters used to reach them.
            let available = try await offeringService.fetchOfferings(
                filter: OfferingFilter(maximumDistanceInMiles: .greatestFiniteMagnitude)
            )
            guard !Task.isCancelled else { return }
            offerings = available.filter { $0.isFromSameProvider(as: offering) }
                .sorted { $0.postedAt > $1.postedAt }
        } catch {
            guard !Task.isCancelled else { return }
            errorMessage = "We couldn’t load this provider’s offers. Please try again."
        }
        isLoading = false
    }
}

private struct PickupLocationSection: View {
    let offering: FoodOffering
    @State private var showsMapsError = false

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            DetailSectionTitle(title: "Pickup location")
            if !offering.providerAddress.isEmpty {
                Text(offering.providerAddress)
                    .font(FullrFont.regular(15))
                    .foregroundStyle(FullrPalette.moss)
                    .textSelection(.enabled)
            }
            if offering.hasPickupCoordinate {
                Map(initialPosition: .region(MKCoordinateRegion(
                    center: offering.coordinate,
                    span: MKCoordinateSpan(latitudeDelta: 0.008, longitudeDelta: 0.008)
                )), interactionModes: []) {
                    Marker(offering.providerName, systemImage: offering.providerType.systemImageName, coordinate: offering.coordinate)
                        .tint(FullrPalette.moss)
                }
                .mapStyle(.standard(elevation: .flat, pointsOfInterest: .excludingAll))
                .frame(height: 180)
                .clipShape(RoundedRectangle(cornerRadius: 24))

                Button {
                    let destination = MKMapItem(location: CLLocation(latitude: offering.coordinate.latitude, longitude: offering.coordinate.longitude), address: nil)
                    destination.name = offering.providerName
                    showsMapsError = !destination.openInMaps(launchOptions: nil)
                } label: {
                    Label("Open in Maps", systemImage: "arrow.up.right")
                }
                .buttonStyle(FullrPrimaryButtonStyle())
                .alert("Could not open Maps", isPresented: $showsMapsError) {
                    Button("OK", role: .cancel) { }
                } message: {
                    Text("Please try again or use the pickup location shown above.")
                }
            } else {
                Text("Map location unavailable. Refer to the pickup address above.")
                    .font(FullrFont.regular(14))
                    .foregroundStyle(FullrPalette.moss)
            }
        }
    }
}

private struct DetailInfoRow: View {
    let title: String
    let value: String
    let systemImage: String

    var body: some View {
        HStack(alignment: .top, spacing: 14) {
            Image(systemName: systemImage)
                .font(FullrFont.medium(19))
                .frame(width: 24)
                .foregroundStyle(FullrPalette.moss)
                .accessibilityHidden(true)
            VStack(alignment: .leading, spacing: 4) {
                Text(title)
                    .font(FullrFont.regular(12, relativeTo: .caption))
                    .foregroundStyle(FullrPalette.moss)
                Text(value)
                    .font(FullrFont.medium(16))
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
        .accessibilityElement(children: .combine)
    }
}

private struct DetailSectionTitle: View {
    let title: String

    var body: some View {
        Text(title)
            .font(FullrFont.semibold(22, relativeTo: .title2))
            .tracking(-0.4)
            .accessibilityAddTraits(.isHeader)
    }
}

private struct DetailPageStyle: ViewModifier {
    let title: String

    func body(content: Content) -> some View {
        content
            .scrollIndicators(.hidden)
            .background(FullrPalette.cream)
            .foregroundStyle(FullrPalette.pine)
            .font(FullrFont.regular(16))
            .tint(FullrPalette.moss)
            .navigationTitle(title)
            .navigationBarTitleDisplayMode(.inline)
            .toolbarRole(.editor)
            .toolbar(.visible, for: .navigationBar)
            .toolbarBackground(FullrPalette.cream, for: .navigationBar)
            .toolbarBackground(.visible, for: .navigationBar)
            .toolbar {
                ToolbarItem(placement: .principal) {
                    Text(title)
                        .font(FullrFont.medium(15))
                        .foregroundStyle(FullrPalette.pine)
                }
            }
    }
}
