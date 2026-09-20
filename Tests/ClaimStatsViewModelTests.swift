import Foundation

@main
struct ClaimStatsViewModelTests {
    @MainActor
    static func main() async throws {
        let firstID = UUID()
        let secondID = UUID()
        let anchor = Date(timeIntervalSince1970: 1_600_000_000.125)
        func page(_ ids: [UUID], next: Int? = nil) -> ClaimStatsPage<RestaurantRanking> {
            ClaimStatsPage(asOf: anchor, totalClaims: 42, totalOffers: 3, totalProviders: 2,
                           items: ids.map { RestaurantRanking(id: $0, name: "Restaurant", rank: 1, claimCount: 21, offerCount: 1) }, nextOffset: next)
        }
        var now = anchor
        var requests: [(StatsPeriod, Date?, Int)] = []
        var shouldFail = false
        let model = ClaimStatsViewModel(now: { now }) { period, _, asOf, offset in
            requests.append((period, asOf, offset))
            if shouldFail { throw URLError(.notConnectedToInternet) }
            if offset == 0 { return page([firstID], next: 25) }
            return page([firstID, secondID])
        }
        await model.load()
        await model.load()
        precondition(requests.count == 1, "Repeat appearances must reuse a fresh cache")
        await model.loadMore()
        precondition(requests.last!.1 == anchor && requests.last!.2 == 25, "Pagination must preserve its time boundary")
        precondition(model.page?.items.map(\.id) == [firstID, secondID], "Paging must deduplicate rows during live changes")
        precondition(model.page?.nextOffset == nil)
        await model.loadMore()
        precondition(requests.count == 2, "Do not fetch past the final page")
        model.period = .week
        await model.load()
        model.period = .month
        await model.load()
        precondition(requests.count == 3 && model.page?.items.count == 2, "Cache each filter independently")
        now = now.addingTimeInterval(61)
        await model.load()
        precondition(requests.count == 4, "Expired cached pages must refresh")
        shouldFail = true
        await model.load(force: true)
        precondition(model.page?.items.count == 1 && model.errorMessage != nil && !model.isLoading,
                     "A refresh error should preserve already-displayed stats")
        shouldFail = false
        model.invalidate()
        await model.load()
        precondition(requests.count == 6 && model.errorMessage == nil, "Claim changes must invalidate stats caches")

        var scopes: [StatsProviderScope] = []
        let scoped = ClaimStatsViewModel<RestaurantRanking> { _, scope, _, _ in
            scopes.append(scope)
            return page(scope == .restaurant ? [] : [firstID])
        }
        await scoped.load()
        precondition(scoped.page?.items.count == 1, "All providers is the default")
        scoped.providerScope = .restaurant
        await scoped.load()
        precondition(scoped.page?.items.isEmpty == true)
        scoped.providerScope = .all
        await scoped.load()
        precondition(scopes == [.all, .restaurant] && scoped.page?.items.count == 1,
                     "Provider-type filters must have independent caches")

        let raced = ClaimStatsViewModel<RestaurantRanking> { period, _, _, _ in
            if period == .month {
                // Simulate a transport completing an obsolete request after cancellation.
                try? await Task.sleep(for: .milliseconds(50))
                return page([firstID])
            }
            return page([secondID])
        }
        let old = Task { await raced.load() }
        await Task.yield()
        raced.period = .week
        await raced.load()
        await old.value
        precondition(raced.page?.items.first?.id == secondID, "An old response must not replace a newer filter")

        var duplicateRequests = 0
        let coalesced = ClaimStatsViewModel<RestaurantRanking> { _, _, _, _ in
            duplicateRequests += 1
            try await Task.sleep(for: .milliseconds(20))
            return page([])
        }
        let one = Task { await coalesced.load() }
        let two = Task { await coalesced.load() }
        await one.value
        await two.value
        precondition(duplicateRequests == 1 && coalesced.page?.items.isEmpty == true)

        let cancelled = ClaimStatsViewModel<RestaurantRanking> { _, _, _, _ in
            try await Task.sleep(for: .seconds(1))
            return page([firstID])
        }
        let cancelledTask = Task { await cancelled.load() }
        await Task.yield()
        cancelledTask.cancel()
        await cancelledTask.value
        precondition(cancelled.page == nil && cancelled.errorMessage == nil && !cancelled.isLoading)

        let payload = try JSONEncoder().encode(ClaimStatsRequest(period: .quarter, storeID: firstID, asOf: anchor, offset: 25, providerScope: .business))
        let json = try JSONSerialization.jsonObject(with: payload) as! [String: Any]
        precondition(json["p_days"] as? Int == 90 && json["p_limit"] as? Int == 25 && json["p_offset"] as? Int == 25)
        precondition(json["p_provider_type"] as? String == "Business")
        precondition(json["p_store_id"] as? String == firstID.uuidString)
        precondition((json["p_as_of"] as? String)?.contains(".125") == true)
        print("Stats view-model tests passed: cache expiry, filter caches, cancellation, request coalescing, race protection, retry, pagination, invalidation, and request encoding.")
    }
}
