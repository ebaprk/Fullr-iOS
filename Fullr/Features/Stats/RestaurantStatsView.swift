import SwiftUI

struct RestaurantStatsView: View {
    let service: RestaurantStatsServicing
    @State private var viewModel: ClaimStatsViewModel<RestaurantRanking>
    @State private var isVisible = false
    @Environment(\.scenePhase) private var scenePhase

    init(service: RestaurantStatsServicing) {
        self.service = service
        _viewModel = State(initialValue: ClaimStatsViewModel { period, providerScope, asOf, offset in
            try await service.fetchRankings(period: period, providerScope: providerScope, asOf: asOf, offset: offset)
        })
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 24) {
                VStack(alignment: .leading, spacing: 8) {
                    Label("COMMUNITY STATS", systemImage: "chart.bar.xaxis")
                        .font(FullrFont.medium(12, relativeTo: .caption))
                        .tracking(1.6)
                        .foregroundStyle(FullrPalette.moss)
                    Text("Good food.\nGreat impact.")
                        .font(FullrFont.semibold(34, relativeTo: .largeTitle))
                        .tracking(-1)
                        .accessibilityAddTraits(.isHeader)
                    Text("See which providers’ offers are claimed most.")
                        .font(FullrFont.regular(15))
                        .foregroundStyle(FullrPalette.moss)
                }

                Menu {
                    Picker("Provider type", selection: $viewModel.providerScope) {
                        ForEach(StatsProviderScope.allCases) { scope in
                            Text(scope.title).tag(scope)
                        }
                    }
                } label: {
                    HStack {
                        Label(viewModel.providerScope.title, systemImage: "line.3.horizontal.decrease")
                        Spacer()
                        Image(systemName: "chevron.down")
                    }
                    .font(FullrFont.medium(15))
                    .foregroundStyle(FullrPalette.moss)
                    .padding(14)
                    .overlay { RoundedRectangle(cornerRadius: 16).strokeBorder(FullrPalette.olive, lineWidth: 1) }
                }
                .accessibilityLabel("Provider type: \(viewModel.providerScope.title)")
                StatsPeriodPicker(period: $viewModel.period)
                Text(viewModel.period.explanation)
                    .font(FullrFont.regular(13))
                    .foregroundStyle(FullrPalette.moss)

                if let page = viewModel.page {
                    StatsSummary(claims: page.totalClaims, offers: page.totalOffers, providers: page.totalProviders)
                }

                HStack {
                    Text("Provider leaderboard")
                        .font(FullrFont.semibold(23, relativeTo: .title2))
                        .accessibilityAddTraits(.isHeader)
                    Spacer()
                    if viewModel.isLoading { ProgressView().tint(FullrPalette.moss) }
                }

                if let error = viewModel.errorMessage {
                    StatsError(message: error) { await viewModel.load(force: true) }
                }
                if let page = viewModel.page {
                    if page.items.isEmpty {
                        FullrEmptyState(title: "No offers from these providers yet", message: "Choose All providers or try a longer time period.", systemImage: "fork.knife")
                    } else {
                        LazyVStack(spacing: 12) {
                            ForEach(page.items) { restaurant in
                                NavigationLink {
                                    RestaurantOfferStatsView(restaurant: restaurant, period: viewModel.period, service: service)
                                } label: {
                                    rankingRow(restaurant)
                                }
                                .buttonStyle(FullrPressStyle())
                                .accessibilityHint("View claims for each offer")
                            }
                        }
                        StatsMoreButton(hasMore: page.nextOffset != nil, isLoading: viewModel.isLoadingMore) { await viewModel.loadMore() }
                    }
                    Text("Ranked by total claims. Each user counts once per offer; equal totals share a rank. Undoing a claim reduces the count.")
                        .font(FullrFont.regular(12, relativeTo: .caption))
                        .foregroundStyle(FullrPalette.moss)
                } else if viewModel.isLoading {
                    ProgressView("Loading provider stats…")
                        .tint(FullrPalette.moss)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 30)
                }
            }
            .frame(maxWidth: 680, alignment: .leading)
            .padding(24)
            .frame(maxWidth: .infinity)
        }
        .modifier(StatsPageStyle())
        .toolbar(.hidden, for: .navigationBar)
        .onAppear { isVisible = true }
        .onDisappear { isVisible = false }
        .task(id: viewModel.filter) { await viewModel.load() }
        .refreshable { await viewModel.load(force: true) }
        .onReceive(NotificationCenter.default.publisher(for: .offerClaimStatusDidChange)) { _ in
            viewModel.invalidate()
            if isVisible { Task { await viewModel.load(force: true) } }
        }
        .onChange(of: scenePhase) { _, phase in
            if phase == .active, isVisible { Task { await viewModel.load() } }
        }
    }

    private func rankingRow(_ restaurant: RestaurantRanking) -> some View {
        HStack(alignment: .center, spacing: 14) {
            Text("\(restaurant.rank)")
                .font(FullrFont.semibold(22))
                .monospacedDigit()
                .frame(minWidth: 42, minHeight: 48)
                .foregroundStyle(restaurant.rank == 1 ? FullrPalette.cream : FullrPalette.moss)
                .background(restaurant.rank == 1 ? FullrPalette.moss : FullrPalette.cream, in: RoundedRectangle(cornerRadius: 14))
            VStack(alignment: .leading, spacing: 5) {
                Text(restaurant.name)
                    .font(FullrFont.semibold(18))
                    .fixedSize(horizontal: false, vertical: true)
                if let type = restaurant.providerType {
                    Text(type).font(FullrFont.regular(12)).foregroundStyle(FullrPalette.moss)
                }
                Text("\(restaurant.offerCount.formatted()) \(restaurant.offerCount == 1 ? "offer" : "offers") · View breakdown")
                    .font(FullrFont.regular(12))
                    .foregroundStyle(FullrPalette.moss)
            }
            Spacer(minLength: 0)
            VStack(alignment: .trailing, spacing: 3) {
                Text(restaurant.claimCount.formatted())
                    .font(FullrFont.semibold(24))
                    .monospacedDigit()
                Text(restaurant.claimCount == 1 ? "claim" : "claims")
                    .font(FullrFont.regular(12))
                    .foregroundStyle(FullrPalette.moss)
            }
        }
        .padding(16)
        .foregroundStyle(FullrPalette.pine)
        .overlay { RoundedRectangle(cornerRadius: 22).strokeBorder(FullrPalette.olive, lineWidth: 1) }
        .accessibilityElement(children: .combine)
        .accessibilityLabel("Rank \(restaurant.rank), \(restaurant.name), \(restaurant.claimCount) claims across \(restaurant.offerCount) offers")
    }
}

private struct RestaurantOfferStatsView: View {
    let restaurant: RestaurantRanking
    @State private var viewModel: ClaimStatsViewModel<RestaurantOfferStats>
    @State private var isVisible = false
    @Environment(\.scenePhase) private var scenePhase

    init(restaurant: RestaurantRanking, period: StatsPeriod, service: RestaurantStatsServicing) {
        self.restaurant = restaurant
        _viewModel = State(initialValue: ClaimStatsViewModel(period: period) { period, providerScope, asOf, offset in
            try await service.fetchOffers(storeID: restaurant.id, period: period, providerScope: providerScope, asOf: asOf, offset: offset)
        })
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 22) {
                Text(restaurant.name)
                    .font(FullrFont.semibold(30, relativeTo: .largeTitle))
                    .accessibilityAddTraits(.isHeader)
                StatsPeriodPicker(period: $viewModel.period)
                Text(viewModel.period.explanation)
                    .font(FullrFont.regular(13))
                    .foregroundStyle(FullrPalette.moss)
                if let page = viewModel.page {
                    StatsSummary(claims: page.totalClaims, offers: page.totalOffers, providers: nil)
                }
                Text("Claims by offer")
                    .font(FullrFont.semibold(23, relativeTo: .title2))
                    .accessibilityAddTraits(.isHeader)
                if viewModel.isLoading { ProgressView("Updating…").tint(FullrPalette.moss) }
                if let error = viewModel.errorMessage {
                    StatsError(message: error) { await viewModel.load(force: true) }
                }
                if let page = viewModel.page {
                    if page.items.isEmpty {
                        FullrEmptyState(title: "No offers in this period", message: "Choose a longer period to see this provider’s offers.", systemImage: "basket")
                    }
                    LazyVStack(spacing: 12) {
                        ForEach(page.items) { offer in
                            HStack(alignment: .top, spacing: 16) {
                                VStack(alignment: .leading, spacing: 6) {
                                    Text(offer.name).font(FullrFont.semibold(17))
                                    Text(offer.postedAt.map { "Posted \($0.formatted(date: .abbreviated, time: .omitted))" } ?? "Posted date unavailable")
                                        .font(FullrFont.regular(12))
                                        .foregroundStyle(FullrPalette.moss)
                                }
                                Spacer(minLength: 0)
                                Text("\(offer.claimCount.formatted()) \(offer.claimCount == 1 ? "claim" : "claims")")
                                    .font(FullrFont.medium(15))
                                    .foregroundStyle(FullrPalette.moss)
                            }
                            .padding(16)
                            .overlay { RoundedRectangle(cornerRadius: 20).strokeBorder(FullrPalette.olive, lineWidth: 1) }
                            .accessibilityElement(children: .combine)
                        }
                    }
                    StatsMoreButton(hasMore: page.nextOffset != nil, isLoading: viewModel.isLoadingMore) { await viewModel.loadMore() }
                }
            }
            .frame(maxWidth: 680, alignment: .leading)
            .padding(24)
            .frame(maxWidth: .infinity)
        }
        .modifier(StatsPageStyle())
        .navigationTitle("Provider stats")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar(.visible, for: .navigationBar)
        .toolbarBackground(FullrPalette.cream, for: .navigationBar)
        .toolbarBackground(.visible, for: .navigationBar)
        .onAppear { isVisible = true }
        .onDisappear { isVisible = false }
        .task(id: viewModel.filter) { await viewModel.load() }
        .refreshable { await viewModel.load(force: true) }
        .onReceive(NotificationCenter.default.publisher(for: .offerClaimStatusDidChange)) { _ in
            viewModel.invalidate()
            if isVisible { Task { await viewModel.load(force: true) } }
        }
        .onChange(of: scenePhase) { _, phase in
            if phase == .active, isVisible { Task { await viewModel.load() } }
        }
    }
}

private struct StatsPeriodPicker: View {
    @Binding var period: StatsPeriod
    var body: some View {
        ScrollView(.horizontal) {
            HStack(spacing: 8) {
                ForEach(StatsPeriod.allCases) { option in
                    Button { period = option } label: {
                        Text(option.title)
                            .font(FullrFont.medium(14))
                            .padding(.horizontal, 18)
                            .frame(minHeight: 44)
                            .foregroundStyle(period == option ? FullrPalette.cream : FullrPalette.moss)
                            .background(period == option ? FullrPalette.moss : FullrPalette.cream, in: Capsule())
                            .overlay { Capsule().strokeBorder(FullrPalette.moss, lineWidth: 1) }
                    }
                    .buttonStyle(FullrPressStyle())
                    .accessibilityLabel("Offers posted: \(option.title)")
                    .accessibilityAddTraits(period == option ? .isSelected : [])
                }
            }
        }
        .scrollIndicators(.hidden)
    }
}

private struct StatsSummary: View {
    let claims: Int
    let offers: Int
    let providers: Int?
    @Environment(\.dynamicTypeSize) private var dynamicTypeSize

    var body: some View {
        let layout = dynamicTypeSize.isAccessibilitySize ? AnyLayout(VStackLayout(alignment: .leading, spacing: 18)) : AnyLayout(HStackLayout(alignment: .top, spacing: 12))
        layout {
            metric(claims, title: "Claims")
            metric(offers, title: "Offers")
            if let providers { metric(providers, title: "Providers") }
        }
        .padding(20)
        .foregroundStyle(FullrPalette.cream)
        .background(FullrPalette.moss, in: RoundedRectangle(cornerRadius: 24))
    }

    private func metric(_ number: Int, title: String) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(number.formatted()).font(FullrFont.semibold(28)).monospacedDigit().minimumScaleFactor(0.7)
            Text(title).font(FullrFont.regular(12))
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .accessibilityElement(children: .combine)
    }
}

private struct StatsError: View {
    let message: String
    let retry: () async -> Void
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text(message).font(FullrFont.regular(14))
            Button("Refresh stats") { Task { await retry() } }.buttonStyle(FullrPrimaryButtonStyle())
        }
    }
}

private struct StatsMoreButton: View {
    let hasMore: Bool
    let isLoading: Bool
    let load: () async -> Void
    var body: some View {
        if isLoading {
            ProgressView("Loading more…").tint(FullrPalette.moss).frame(maxWidth: .infinity)
        } else if hasMore {
            Button("Load more") { Task { await load() } }.buttonStyle(FullrPrimaryButtonStyle())
        }
    }
}

private struct StatsPageStyle: ViewModifier {
    func body(content: Content) -> some View {
        content.scrollIndicators(.hidden)
            .background(FullrPalette.cream)
            .foregroundStyle(FullrPalette.pine)
            .font(FullrFont.regular(16))
            .tint(FullrPalette.moss)
    }
}

#Preview {
    NavigationStack { RestaurantStatsView(service: MockRestaurantStatsService()) }
}
