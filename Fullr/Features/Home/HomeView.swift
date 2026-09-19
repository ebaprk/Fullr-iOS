import SwiftUI
import Kingfisher

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
                            .frame(height: 420)
                            .offset(y: -420)
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
        .coordinateSpace(name: "homeScroll")
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
            let headerOffset = proxy.frame(in: .named("homeScroll")).minY

            ZStack(alignment: .top) {
                FullrPalette.cream

                VStack(spacing: 0) {
                    Spacer(minLength: topInset + 92)
                    HomeLandscape(scrollOffset: headerOffset)
                        .frame(height: 190)
                }

                HStack(alignment: .center) {
                    HStack(spacing: 8) {
                        Text("FULLR")
                            .font(.system(size: 39, weight: .heavy, design: .serif))
                        Image("Food")
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
        .frame(height: 326)
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

            HStack(spacing: 0) {
                ForEach(OfferingFilter.distanceOptionsInMiles, id: \.self) { distance in
                    Button {
                        Task { await viewModel.updateDistance(distance) }
                    } label: {
                        Text("\(Int(distance)) mi")
                            .font(.subheadline.weight(.bold))
                            .frame(maxWidth: .infinity)
                            .frame(height: 44)
                            .background(distance == viewModel.filter.maximumDistanceInMiles ? FullrPalette.cream : FullrPalette.moss, in: Capsule())
                            .foregroundStyle(distance == viewModel.filter.maximumDistanceInMiles ? FullrPalette.pine : FullrPalette.cream)
                    }
                    .buttonStyle(.plain)
                }
            }
            .padding(4)
            .background(FullrPalette.olive, in: Capsule())
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
    let scrollOffset: Double

    private var parallaxOffset: Double {
        min(max(scrollOffset, 0), 180)
    }

    var body: some View {
        ZStack(alignment: .bottom) {
            FullrPalette.cream

            BackMountain()
                .fill(FullrPalette.olive)
                .frame(height: 220)
                .offset(y: 4 + parallaxOffset * 0.10)

            ShadowMountain()
                .fill(FullrPalette.ink)
                .frame(height: 190)
                .offset(y: 34 + parallaxOffset * 0.28)

            MiddleMountain()
                .fill(FullrPalette.pine)
                .frame(height: 176)
                .offset(y: 38 + parallaxOffset * 0.45)

            ForegroundMountain()
                .fill(FullrPalette.moss)
                .frame(height: 190)
                .offset(y: 74 + parallaxOffset * 0.68)
        }
        .clipped()
    }
}

private struct BackMountain: Shape {
    func path(in rect: CGRect) -> Path {
        var path = Path()

        path.move(to: CGPoint(x: rect.minX, y: rect.height * 0.58))
        path.addCurve(
            to: CGPoint(x: rect.width * 0.72, y: rect.height * 0.26),
            control1: CGPoint(x: rect.width * 0.24, y: rect.height * 0.62),
            control2: CGPoint(x: rect.width * 0.42, y: rect.height * 0.16)
        )
        path.addCurve(
            to: CGPoint(x: rect.maxX, y: rect.height * 0.36),
            control1: CGPoint(x: rect.width * 0.86, y: rect.height * 0.27),
            control2: CGPoint(x: rect.width * 0.94, y: rect.height * 0.34)
        )
        path.addLine(to: CGPoint(x: rect.maxX, y: rect.maxY))
        path.addLine(to: CGPoint(x: rect.minX, y: rect.maxY))
        path.closeSubpath()

        return path
    }
}

private struct ShadowMountain: Shape {
    func path(in rect: CGRect) -> Path {
        var path = Path()

        path.move(to: CGPoint(x: rect.minX, y: rect.height * 0.30))
        path.addCurve(
            to: CGPoint(x: rect.width * 0.62, y: rect.height * 0.42),
            control1: CGPoint(x: rect.width * 0.18, y: rect.height * 0.15),
            control2: CGPoint(x: rect.width * 0.38, y: rect.height * 0.24)
        )
        path.addCurve(
            to: CGPoint(x: rect.maxX, y: rect.height * 0.18),
            control1: CGPoint(x: rect.width * 0.78, y: rect.height * 0.52),
            control2: CGPoint(x: rect.width * 0.90, y: rect.height * 0.28)
        )
        path.addLine(to: CGPoint(x: rect.maxX, y: rect.maxY))
        path.addLine(to: CGPoint(x: rect.minX, y: rect.maxY))
        path.closeSubpath()

        return path
    }
}

private struct MiddleMountain: Shape {
    func path(in rect: CGRect) -> Path {
        var path = Path()

        path.move(to: CGPoint(x: rect.minX, y: rect.height * 0.58))
        path.addCurve(
            to: CGPoint(x: rect.width * 0.60, y: rect.height * 0.50),
            control1: CGPoint(x: rect.width * 0.20, y: rect.height * 0.82),
            control2: CGPoint(x: rect.width * 0.42, y: rect.height * 0.68)
        )
        path.addCurve(
            to: CGPoint(x: rect.maxX, y: rect.height * 0.12),
            control1: CGPoint(x: rect.width * 0.78, y: rect.height * 0.32),
            control2: CGPoint(x: rect.width * 0.90, y: rect.height * 0.26)
        )
        path.addLine(to: CGPoint(x: rect.maxX, y: rect.maxY))
        path.addLine(to: CGPoint(x: rect.minX, y: rect.maxY))
        path.closeSubpath()

        return path
    }
}

private struct ForegroundMountain: Shape {
    func path(in rect: CGRect) -> Path {
        var path = Path()

        path.move(to: CGPoint(x: rect.minX, y: rect.height * 0.28))
        path.addCurve(
            to: CGPoint(x: rect.width * 0.26, y: rect.height * 0.45),
            control1: CGPoint(x: rect.width * 0.08, y: rect.height * 0.34),
            control2: CGPoint(x: rect.width * 0.16, y: rect.height * 0.47)
        )
        path.addCurve(
            to: CGPoint(x: rect.width * 0.72, y: rect.height * 0.42),
            control1: CGPoint(x: rect.width * 0.42, y: rect.height * 0.58),
            control2: CGPoint(x: rect.width * 0.58, y: rect.height * 0.52)
        )
        path.addCurve(
            to: CGPoint(x: rect.maxX, y: rect.height * 0.24),
            control1: CGPoint(x: rect.width * 0.84, y: rect.height * 0.34),
            control2: CGPoint(x: rect.width * 0.92, y: rect.height * 0.20)
        )
        path.addLine(to: CGPoint(x: rect.maxX, y: rect.maxY))
        path.addLine(to: CGPoint(x: rect.minX, y: rect.maxY))
        path.closeSubpath()

        return path
    }
}

private struct StoreImageCard: View {
    let offering: FoodOffering

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            ZStack(alignment: .bottomLeading) {
                StoreImage(url: offering.imageURL, providerType: offering.providerType)
                    .frame(height: 128)
                    .clipped()

                LinearGradient(
                    colors: [.clear, FullrPalette.pine.opacity(0.55)],
                    startPoint: .center,
                    endPoint: .bottom
                )

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

private struct StoreImage: View {
    let url: URL?
    let providerType: ProviderType

    var body: some View {
        KFImage(url)
            .placeholder { FoodImageArtwork(providerType: providerType) }
            .resizable()
            .fade(duration: 0.25)
            .aspectRatio(contentMode: .fill)
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
