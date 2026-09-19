import SwiftUI

struct HomeView: View {
    @State var viewModel: HomeViewModel
    @State private var showsFilters = false
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var headerScrollOffset: CGFloat = 0
    @State private var restingScrollOffset: CGFloat?

    private var featuredOfferings: [FoodOffering] {
        Array(viewModel.offerings.prefix(5))
    }

    var body: some View {
        GeometryReader { geometry in
            ScrollView {
                VStack(alignment: .leading, spacing: 24) {
                    header(topInset: geometry.safeAreaInsets.top)

                    VStack(alignment: .leading, spacing: 24) {
                        searchBar

                        if showsFilters {
                            VStack(alignment: .leading, spacing: 12) {
                                HStack {
                                    Text("Your pickup radius")
                                        .font(FullrFont.medium(14, relativeTo: .subheadline))
                                    Spacer()
                                    Text("\(Int(viewModel.filter.maximumDistanceInMiles)) \(viewModel.filter.maximumDistanceInMiles == 1 ? "mile" : "miles")")
                                        .font(FullrFont.regular(13, relativeTo: .caption))
                                }
                                .foregroundStyle(FullrPalette.moss)

                                FullrDistancePicker(selectedDistance: viewModel.filter.maximumDistanceInMiles) { distance in
                                    Task { await viewModel.updateDistance(distance) }
                                }
                            }
                        }

                        providerCategories
                        content
                    }
                    .frame(maxWidth: 680)
                    .padding(.horizontal, 24)
                    .frame(maxWidth: .infinity)
                    .padding(.bottom, 28)
                }
            }
            .onScrollGeometryChange(for: CGFloat.self) { scroll in
                scroll.contentOffset.y + scroll.contentInsets.top
            } action: { _, offset in
                // Normalize the initial safe-area inset before applying parallax.
                if restingScrollOffset == nil { restingScrollOffset = offset }
                headerScrollOffset = (restingScrollOffset ?? offset) - offset
            }
            .scrollIndicators(.hidden)
            .scrollDismissesKeyboard(.interactively)
            .ignoresSafeArea(edges: .top)
            .overlay(alignment: .top) {
                FullrPalette.cream
                    .frame(height: geometry.safeAreaInsets.top)
                    .frame(maxHeight: .infinity, alignment: .top)
                    .ignoresSafeArea(edges: .top)
                    .allowsHitTesting(false)
                    .accessibilityHidden(true)
            }
        }
        .background(FullrPalette.cream)
        .font(FullrFont.regular(16))
        .foregroundStyle(FullrPalette.pine)
        .toolbar(.hidden, for: .navigationBar)
        .task {
            viewModel.requestLocationIfNeeded()
            await viewModel.loadOfferings()
        }
        .refreshable { await viewModel.loadOfferings() }
        .onChange(of: viewModel.filter.searchText) { viewModel.scheduleLoadOfferings() }
        .alert("Could not load offerings", isPresented: errorIsPresented) {
            Button("OK") { viewModel.errorMessage = nil }
        } message: {
            Text(viewModel.errorMessage ?? "")
        }
    }

    private func header(topInset: CGFloat) -> some View {
        VStack(spacing: 0) {
            VStack(alignment: .leading, spacing: 18) {
                HStack(alignment: .center) {
                    FullrWordmark()
                    Spacer()
                    Text("Less waste.\nMore goodness.")
                        .font(FullrFont.regular(12, relativeTo: .caption))
                        .multilineTextAlignment(.trailing)
                        .foregroundStyle(FullrPalette.moss)
                }

                VStack(alignment: .leading, spacing: 10) {
                    Text("Good food.\nCloser to home.")
                        .font(FullrFont.medium(38, relativeTo: .largeTitle))
                        .tracking(-1.4)
                        .lineSpacing(-2)
                        .fixedSize(horizontal: false, vertical: true)
                        .accessibilityAddTraits(.isHeader)
                    Text("A little local. A lot to love.")
                        .font(FullrFont.regular(15, relativeTo: .subheadline))
                        .foregroundStyle(FullrPalette.moss)
                }
            }
            .frame(maxWidth: 680, alignment: .leading)
            .padding(.horizontal, 26)
            .padding(.top, topInset + 12)
            .frame(maxWidth: .infinity)
            .zIndex(-1)

            HomeLandscape(scrollOffset: headerScrollOffset)
                .frame(height: 150)
                .accessibilityHidden(true)
        }
    }

    private var searchBar: some View {
        HStack(spacing: 10) {
            HStack(spacing: 10) {
                Image(systemName: "magnifyingglass")
                    .font(FullrFont.medium(18))
                    .foregroundStyle(FullrPalette.moss)
                TextField("Find something good", text: $viewModel.filter.searchText, prompt:
                    Text("Find something good").foregroundStyle(FullrPalette.moss)
                )
                .font(FullrFont.regular(15, relativeTo: .subheadline))
                .textInputAutocapitalization(.never)
                .autocorrectionDisabled()
                .submitLabel(.search)
                .accessibilityLabel("Search food or providers")
                .onSubmit { Task { await viewModel.loadOfferings() } }

                if !viewModel.filter.searchText.isEmpty {
                    Button { viewModel.filter.searchText = "" } label: {
                        Image(systemName: "xmark")
                            .font(FullrFont.medium(12))
                            .frame(width: 32, height: 44)
                    }
                    .buttonStyle(.plain)
                    .accessibilityLabel("Clear search")
                }
            }
            .padding(.horizontal, 18)
            .frame(minHeight: 54)
            .overlay { Capsule().strokeBorder(FullrPalette.olive, lineWidth: 1) }

            Button {
                withAnimation(reduceMotion ? nil : .easeInOut(duration: 0.22)) { showsFilters.toggle() }
            } label: {
                Image(systemName: "slider.horizontal.3")
                    .font(FullrFont.medium(19))
                    .frame(width: 54, height: 54)
                    .foregroundStyle(FullrPalette.cream)
                    .background(FullrPalette.moss, in: Circle())
            }
            .buttonStyle(FullrPressStyle())
            .accessibilityLabel(showsFilters ? "Hide distance filters" : "Show distance filters")
            .accessibilityValue("Within \(Int(viewModel.filter.maximumDistanceInMiles)) \(viewModel.filter.maximumDistanceInMiles == 1 ? "mile" : "miles")")
        }
    }

    private var providerCategories: some View {
        ScrollView(.horizontal) {
            HStack(spacing: 8) {
                ProviderCategoryButton(title: "All food", systemImage: "sparkles", isSelected: viewModel.filter.providerType == nil) {
                    Task { await viewModel.updateProviderType(nil) }
                }
                ForEach(ProviderType.allCases) { provider in
                    ProviderCategoryButton(title: provider.displayName, systemImage: provider.systemImageName, isSelected: viewModel.filter.providerType == provider) {
                        Task { await viewModel.updateProviderType(provider) }
                    }
                }
            }
        }
        .scrollIndicators(.hidden)
    }

    @ViewBuilder
    private var content: some View {
        if viewModel.isLoading {
            ProgressView("Finding local goodness…")
                .font(FullrFont.regular(15))
                .tint(FullrPalette.moss)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 48)
        } else if viewModel.offerings.isEmpty {
            FullrEmptyState(title: "More good food soon", message: "Try another search or widen your pickup radius to find food nearby.", systemImage: "basket")
        } else {
            featuredSection
            nearbySection
        }
    }

    private var featuredSection: some View {
        VStack(alignment: .leading, spacing: 16) {
            sectionHeader(title: "Fresh finds", subtitle: "Good food, ready for a second chance.")
            ScrollView(.horizontal) {
                HStack(alignment: .top, spacing: 14) {
                    ForEach(featuredOfferings) { offering in
                        NavigationLink {
                            OfferingDetailView(offering: offering, offeringService: viewModel.offeringService)
                        } label: {
                            FeaturedOfferingCard(offering: offering)
                                .frame(width: 274)
                        }
                        .buttonStyle(FullrPressStyle())
                        .accessibilityHint("Opens offer details")
                    }
                }
                .scrollTargetLayout()
            }
            .scrollTargetBehavior(.viewAligned)
            .scrollIndicators(.hidden)
        }
    }

    private var nearbySection: some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack(alignment: .firstTextBaseline) {
                sectionHeader(title: "Around you", subtitle: "Small pickups. Big difference.")
                Spacer()
                Text("\(viewModel.offerings.count) \(viewModel.offerings.count == 1 ? "offer" : "offers")")
                    .font(FullrFont.medium(12, relativeTo: .caption))
                    .foregroundStyle(FullrPalette.moss)
            }

            LazyVStack(spacing: 12) {
                ForEach(viewModel.offerings) { offering in
                    NavigationLink {
                        OfferingDetailView(offering: offering, offeringService: viewModel.offeringService)
                    } label: {
                        FoodOfferingCard(offering: offering)
                    }
                    .buttonStyle(FullrPressStyle())
                    .accessibilityHint("Opens offer details")
                }
            }
        }
    }

    private func sectionHeader(title: String, subtitle: String) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(title)
                .font(FullrFont.semibold(25, relativeTo: .title2))
                .tracking(-0.6)
                .accessibilityAddTraits(.isHeader)
            Text(subtitle)
                .font(FullrFont.regular(13, relativeTo: .subheadline))
                .foregroundStyle(FullrPalette.moss)
        }
    }

    private var errorIsPresented: Binding<Bool> {
        Binding(get: { viewModel.errorMessage != nil }, set: { if !$0 { viewModel.errorMessage = nil } })
    }
}

private struct ProviderCategoryButton: View {
    let title: String
    let systemImage: String
    let isSelected: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            Label(title, systemImage: systemImage)
                .font(FullrFont.medium(13, relativeTo: .subheadline))
                .padding(.horizontal, 16)
                .frame(minHeight: 44)
                .foregroundStyle(isSelected ? FullrPalette.cream : FullrPalette.moss)
                .background(isSelected ? FullrPalette.moss : FullrPalette.cream, in: Capsule())
                .overlay { Capsule().strokeBorder(isSelected ? FullrPalette.moss : FullrPalette.olive, lineWidth: 1) }
        }
        .buttonStyle(FullrPressStyle())
        .accessibilityAddTraits(isSelected ? .isSelected : [])
    }
}

struct HomeLandscape: View {
    let scrollOffset: Double
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    private var parallaxOffset: Double {
        // Counter-scroll the hills as the header leaves the screen; pull-down
        // stretches the same layers. Positive offsets keep their bases covered.
        reduceMotion ? 0 : max(scrollOffset, -70)
    }

    var body: some View {
        GeometryReader { geometry in
            ZStack(alignment: .bottom) {
                FullrPalette.cream

                Circle()
                    .strokeBorder(FullrPalette.gold, lineWidth: 1)
                    .frame(width: 50, height: 50)
                    .frame(maxWidth: .infinity, alignment: .trailing)
                    .padding(.trailing, 45)
                    .offset(y: -90 + parallaxOffset * 0.05)

                BackMountain()
                    .fill(FullrPalette.olive)
                    .frame(height: 184)
                    .offset(y: 10 + parallaxOffset * 0.10)

                ShadowMountain()
                    .fill(FullrPalette.moss)
                    .frame(height: 148)
                    .offset(y: 22 + parallaxOffset * 0.28)

                MiddleMountain()
                    .fill(FullrPalette.pine)
                    .frame(height: 132)
                    .offset(y: 32 + parallaxOffset * 0.45)

                ForegroundMountain()
                    .fill(FullrPalette.cream)
                    .frame(height: 108)
                    .offset(y: 56 + parallaxOffset * 0.68)
            }
            .frame(width: geometry.size.width, height: geometry.size.height, alignment: .bottom)
            .clipped()
        }
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


#Preview {
    NavigationStack {
        HomeView(viewModel: HomeViewModel(offeringService: MockFoodOfferingService()))
    }
}
