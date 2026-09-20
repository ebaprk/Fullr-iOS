import Foundation

@MainActor
protocol RestaurantStatsServicing {
    func fetchRankings(period: StatsPeriod, providerScope: StatsProviderScope, asOf: Date?, offset: Int) async throws -> ClaimStatsPage<RestaurantRanking>
    func fetchOffers(storeID: UUID, period: StatsPeriod, providerScope: StatsProviderScope, asOf: Date?, offset: Int) async throws -> ClaimStatsPage<RestaurantOfferStats>
}

struct SupabaseRestaurantStatsService: RestaurantStatsServicing {
    private let client: FullrSupabaseClient?
    private let sessionProvider: () async throws -> SupabaseStoredSession

    init(client: FullrSupabaseClient? = SupabaseClientProvider.makeClient(), sessionProvider: @escaping () async throws -> SupabaseStoredSession) {
        self.client = client
        self.sessionProvider = sessionProvider
    }

    func fetchRankings(period: StatsPeriod, providerScope: StatsProviderScope, asOf: Date?, offset: Int) async throws -> ClaimStatsPage<RestaurantRanking> {
        guard let client else { throw AuthenticationError.missingSupabaseConfiguration }
        return try await client.fetchClaimStats(
            request: ClaimStatsRequest(period: period, storeID: nil, asOf: asOf, offset: offset, providerScope: providerScope),
            session: sessionProvider()
        )
    }

    func fetchOffers(storeID: UUID, period: StatsPeriod, providerScope: StatsProviderScope, asOf: Date?, offset: Int) async throws -> ClaimStatsPage<RestaurantOfferStats> {
        guard let client else { throw AuthenticationError.missingSupabaseConfiguration }
        return try await client.fetchClaimStats(
            request: ClaimStatsRequest(period: period, storeID: storeID, asOf: asOf, offset: offset, providerScope: providerScope),
            session: sessionProvider()
        )
    }
}

struct MockRestaurantStatsService: RestaurantStatsServicing {
    func fetchRankings(period: StatsPeriod, providerScope: StatsProviderScope, asOf: Date?, offset: Int) async throws -> ClaimStatsPage<RestaurantRanking> {
        ClaimStatsPage(asOf: asOf ?? Date(), totalClaims: 42, totalOffers: 3, totalProviders: 1,
                       items: [RestaurantRanking(id: UUID(), name: "Main Street Bagels", rank: 1, claimCount: 42, offerCount: 3)], nextOffset: nil)
    }

    func fetchOffers(storeID: UUID, period: StatsPeriod, providerScope: StatsProviderScope, asOf: Date?, offset: Int) async throws -> ClaimStatsPage<RestaurantOfferStats> {
        ClaimStatsPage(asOf: asOf ?? Date(), totalClaims: 42, totalOffers: 3, totalProviders: 1,
                       items: [
                        RestaurantOfferStats(id: UUID(), name: "Fresh bagels", postedAt: Date(), claimCount: 20),
                        RestaurantOfferStats(id: UUID(), name: "Bagels and spreads", postedAt: Date().addingTimeInterval(-86_400), claimCount: 14),
                        RestaurantOfferStats(id: UUID(), name: "Breakfast box", postedAt: Date().addingTimeInterval(-172_800), claimCount: 8)
                       ], nextOffset: nil)
    }
}
