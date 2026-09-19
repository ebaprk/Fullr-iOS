import SwiftUI

struct HomeView: View {
    @State var viewModel: HomeViewModel
    @State private var showsFilters = true

    private var featuredOfferings: [FoodOffering] {
        Array(viewModel.offerings.prefix(5))
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 24) {
                header
                    .background(alignment: .top) {
                        FullrPalette.cream
                            .frame(height: 320)
                            .offset(y: -220)
                    }
                VStack(alignment: .leading, spacing: 22) {
                    searchBar
                    if showsFilters {
                        distanceFilter
                        providerCategories
                    }
                    content
                }
                .padding(.horizontal, 16)
                .padding(.bottom, 24)
            }
        }
        .background(FullrPalette.moss)
        .toolbar(.hidden, for: .navigationBar)
        .task {
            viewModel.requestLocationIfNeeded()
            await viewModel.loadOfferings()
        }
        .refreshable { await viewModel.loadOfferings() }
        .onChange(of: viewModel.filter.searchText) {
            viewModel.scheduleLoadOfferings()
        }
        .alert("Could not load offerings", isPresented: errorIsPresented) {
            Button("OK") { viewModel.errorMessage = nil }
        } message: {
            Text(viewModel.errorMessage ?? "")
        }
        .ignoresSafeArea(.all, edges: .all)
    }

    private var header: some View {
        GeometryReader { proxy in
            let topInset = proxy.safeAreaInsets.top
            let controlTopPadding = max(topInset + 22, 96)

            ZStack(alignment: .top) {
                FullrPalette.cream

                VStack(spacing: 0) {
                    Spacer(minLength: topInset + 92)
                    HomeLandscape()
                        .frame(height: 150)
                }

                HStack(alignment: .center) {
                    HStack(spacing: 8) {
                        Image(systemName: "leaf.circle.fill")
                            .font(.system(size: 43, weight: .black))

                        Text("FULLR")
                            .font(.system(size: 39, weight: .heavy, design: .serif))
                    }
                    .foregroundStyle(FullrPalette.pine)

                    Spacer()

                    Button { showsFilters.toggle() } label: {
                        Image(systemName: showsFilters ? "line.3.horizontal.decrease.circle.fill" : "person.crop.circle.fill")
                            .font(.title)
                            .frame(width: 48, height: 48)
                            .background(FullrPalette.moss, in: Circle())
                            .foregroundStyle(FullrPalette.cream)
                    }
                    .buttonStyle(.plain)
                    .accessibilityLabel("Filters")
                }
                .padding(.horizontal, 16)
                .padding(.top, controlTopPadding)
            }
        }
        .frame(height: 286)
        .clipShape(UnevenRoundedRectangle(bottomLeadingRadius: 28, bottomTrailingRadius: 28))
    }

    private var statusPills: some View {
        HStack(spacing: 10) {
            InfoPill(title: "Free pickup", systemImage: "takeoutbag.and.cup.and.straw")
            InfoPill(title: "\(viewModel.offerings.count) active", systemImage: "bolt.fill")
        }
    }

    private var homeIntro: some View {
        VStack(alignment: .leading, spacing: 8) {
            statusPills

            Text("Fresh offers from local stores")
                .font(.title.bold())
                .foregroundStyle(FullrPalette.cream)
                .fixedSize(horizontal: false, vertical: true)
        }
    }

    private var searchBar: some View {
        VStack(alignment: .leading, spacing: 16) {
            homeIntro

            HStack(spacing: 10) {
                Image(systemName: "magnifyingglass")
                    .foregroundStyle(FullrPalette.moss)

                TextField("Search food or providers", text: $viewModel.filter.searchText)
                    .textInputAutocapitalization(.never)
                    .autocorrectionDisabled()
                    .submitLabel(.search)
                    .foregroundStyle(FullrPalette.pine)
                    .onSubmit { Task { await viewModel.loadOfferings() } }

                if !viewModel.filter.searchText.isEmpty {
                    Button {
                        viewModel.filter.searchText = ""
                    } label: {
                        Image(systemName: "xmark.circle.fill")
                            .foregroundStyle(FullrPalette.moss)
                    }
                    .buttonStyle(.plain)
                    .accessibilityLabel("Clear search")
                }
            }
            .padding(.horizontal, 14)
            .frame(height: 50)
            .background(FullrPalette.cream, in: RoundedRectangle(cornerRadius: 8))
        }
    }

    private var providerCategories: some View {
        VStack(alignment: .leading, spacing: 12) {
            sectionHeader(title: "Browse by store", actionTitle: nil)

            ScrollView(.horizontal) {
                HStack(spacing: 12) {
                    ProviderCategoryButton(
                        title: "All",
                        systemImage: "square.grid.2x2.fill",
                        isSelected: viewModel.filter.providerType == nil
                    ) {
                        Task { await viewModel.updateProviderType(nil) }
                    }

                    ForEach(ProviderType.allCases) { providerType in
                        ProviderCategoryButton(
                            title: providerType.displayName,
                            systemImage: providerType.systemImageName,
                            isSelected: viewModel.filter.providerType == providerType
                        ) {
                            Task { await viewModel.updateProviderType(providerType) }
                        }
                    }
                }
                .padding(.vertical, 2)
            }
            .scrollIndicators(.hidden)
        }
    }

    private var distanceFilter: some View {
        VStack(alignment: .leading, spacing: 12) {
            sectionHeader(title: "Distance", actionTitle: nil)

            Picker("Distance", selection: distanceBinding) {
                ForEach(OfferingFilter.distanceOptionsInMiles, id: \.self) { distance in
                    Text("\(Int(distance)) mi").tag(distance)
                }
            }
            .pickerStyle(.segmented)
            .tint(FullrPalette.gold)
        }
    }

    @ViewBuilder
    private var content: some View {
        if viewModel.isLoading {
            ProgressView()
                .tint(FullrPalette.cream)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 48)
        } else if viewModel.offerings.isEmpty {
            ContentUnavailableView(
                "No offerings found",
                systemImage: "tray",
                description: Text("Try widening your filters or checking again soon.")
            )
            .padding(.vertical, 48)
        } else {
            featuredSection
            nearbySection
        }
    }

    private var featuredSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            sectionHeader(title: "Favorites", actionTitle: nil)

            ScrollView(.horizontal) {
                HStack(spacing: 14) {
                    ForEach(featuredOfferings) { offering in
                        StoreImageCard(offering: offering)
                            .frame(width: 294, height: 204)
                    }
                }
                .padding(.vertical, 2)
            }
            .scrollIndicators(.hidden)
        }
    }

    private var nearbySection: some View {
        VStack(alignment: .leading, spacing: 12) {
            sectionHeader(title: "Offers", actionTitle: nil)

            VStack(spacing: 12) {
                ForEach(viewModel.offerings) { offering in
                    FoodOfferingCard(offering: offering)
                }
            }
        }
    }

    private func sectionHeader(title: String, actionTitle: String?) -> some View {
        HStack {
            Text(title)
                .font(.title3.bold())
                .foregroundStyle(FullrPalette.cream)
            Spacer()
            if let actionTitle {
                Button(actionTitle) { }
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(FullrPalette.gold)
            }
        }
    }

    private var distanceBinding: Binding<Double> {
        Binding(
            get: { viewModel.filter.maximumDistanceInMiles },
            set: { newValue in Task { await viewModel.updateDistance(newValue) } }
        )
    }

    private var errorIsPresented: Binding<Bool> {
        Binding(get: { viewModel.errorMessage != nil }, set: { if !$0 { viewModel.errorMessage = nil } })
    }
}

private struct InfoPill: View {
    let title: String
    let systemImage: String

    var body: some View {
        Label(title, systemImage: systemImage)
            .font(.caption.weight(.semibold))
            .padding(.horizontal, 10)
            .padding(.vertical, 7)
            .background(FullrPalette.olive, in: Capsule())
            .foregroundStyle(FullrPalette.cream)
    }
}

private struct ProviderCategoryButton: View {
    let title: String
    let systemImage: String
    let isSelected: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            VStack(spacing: 8) {
                Image(systemName: systemImage)
                    .font(.title3)
                    .frame(width: 46, height: 46)
                    .background(isSelected ? FullrPalette.gold : FullrPalette.cream, in: RoundedRectangle(cornerRadius: 8))
                    .foregroundStyle(isSelected ? FullrPalette.pine : FullrPalette.moss)

                Text(title)
                    .font(.caption.weight(.semibold))
                    .lineLimit(1)
                    .minimumScaleFactor(0.8)
                    .foregroundStyle(FullrPalette.cream)
            }
            .frame(width: 74)
        }
        .buttonStyle(.plain)
    }
}

private struct HomeLandscape: View {
    var body: some View {
        ZStack(alignment: .bottom) {
            FullrPalette.cream

            UnevenRoundedRectangle(topLeadingRadius: 160, bottomLeadingRadius: 0, bottomTrailingRadius: 0, topTrailingRadius: 80)
                .fill(FullrPalette.olive)
                .frame(height: 110)
                .offset(x: 118, y: 4)

            UnevenRoundedRectangle(topLeadingRadius: 0, bottomLeadingRadius: 0, bottomTrailingRadius: 0, topTrailingRadius: 180)
                .fill(FullrPalette.ink)
                .frame(height: 102)
                .offset(x: -82, y: 28)

            UnevenRoundedRectangle(topLeadingRadius: 120, bottomLeadingRadius: 0, bottomTrailingRadius: 0, topTrailingRadius: 12)
                .fill(FullrPalette.pine)
                .frame(height: 76)
                .offset(x: 116, y: 42)

            UnevenRoundedRectangle(topLeadingRadius: 0, bottomLeadingRadius: 0, bottomTrailingRadius: 0, topTrailingRadius: 130)
                .fill(FullrPalette.moss)
                .frame(height: 72)
                .offset(x: -104, y: 56)
        }
        .clipped()
    }
}

private struct StoreImageCard: View {
    let offering: FoodOffering

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            ZStack(alignment: .bottomLeading) {
                FoodImageArtwork(providerType: offering.providerType)

                Text(offering.providerName)
                    .font(.title2.bold())
                    .foregroundStyle(FullrPalette.cream)
                    .lineLimit(2)
                    .padding(14)
            }

            HStack {
                Text(offering.title)
                    .font(.subheadline.weight(.semibold))
                    .lineLimit(1)
                    .foregroundStyle(FullrPalette.pine)

                Spacer()

                Text(offering.badgeText)
                    .font(.caption.weight(.bold))
                    .foregroundStyle(FullrPalette.gold)
            }
            .padding(12)
            .background(FullrPalette.cream)
        }
        .clipShape(RoundedRectangle(cornerRadius: 8))
    }
}

private struct FoodImageArtwork: View {
    let providerType: ProviderType

    var body: some View {
        ZStack {
            FullrPalette.gold
            HillArtwork()

            HStack(spacing: 10) {
                ForEach(0..<4, id: \.self) { index in
                    Circle()
                        .fill(index.isMultiple(of: 2) ? FullrPalette.cream : FullrPalette.olive)
                        .frame(width: 58, height: 58)
                        .overlay {
                            Image(systemName: providerType.systemImageName)
                                .font(.title3)
                                .foregroundStyle(FullrPalette.pine)
                        }
                }
            }
            .offset(x: 26, y: -8)
        }
    }
}

#Preview {
    NavigationStack {
        HomeView(viewModel: HomeViewModel(offeringService: MockFoodOfferingService()))
    }
}
