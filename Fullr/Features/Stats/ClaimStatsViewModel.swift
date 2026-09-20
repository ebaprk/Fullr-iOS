import Foundation
import Observation

@MainActor
@Observable
final class ClaimStatsViewModel<Row: Decodable & Identifiable> {
    typealias Loader = (StatsPeriod, StatsProviderScope, Date?, Int) async throws -> ClaimStatsPage<Row>
    private let loader: Loader
    private let now: () -> Date
    private let cacheLifetime: TimeInterval = 60
    private var cache: [StatsFilter: (page: ClaimStatsPage<Row>, fetchedAt: Date)] = [:]
    private var requestTask: Task<ClaimStatsPage<Row>, Error>?
    private var generation = 0
    private var loadedFilter: StatsFilter?
    private var activeFilter: StatsFilter?
    var period: StatsPeriod
    var providerScope: StatsProviderScope = .all
    var filter: StatsFilter { StatsFilter(period: period, providerScope: providerScope) }
    private(set) var page: ClaimStatsPage<Row>?
    private(set) var isLoading = false
    private(set) var isLoadingMore = false
    private(set) var errorMessage: String?

    init(period: StatsPeriod = .month, now: @escaping () -> Date = Date.init, loader: @escaping Loader) {
        self.period = period
        self.now = now
        self.loader = loader
    }

    func invalidate() {
        cache.removeAll()
        requestTask?.cancel()
        generation += 1
        activeFilter = nil
        isLoading = false
        isLoadingMore = false
    }

    func load(force: Bool = false) async {
        let requestedFilter = filter
        if !force, isLoading, activeFilter == requestedFilter { return }
        requestTask?.cancel()
        generation += 1
        let currentGeneration = generation
        activeFilter = requestedFilter
        isLoadingMore = false
        errorMessage = nil
        if let cached = cache[requestedFilter], !force, now().timeIntervalSince(cached.fetchedAt) < cacheLifetime {
            page = cached.page
            loadedFilter = requestedFilter
            isLoading = false
            return
        }
        if loadedFilter != requestedFilter { page = cache[requestedFilter]?.page }
        loadedFilter = requestedFilter
        isLoading = true
        let task = Task { try await loader(requestedFilter.period, requestedFilter.providerScope, nil, 0) }
        requestTask = task
        defer { if generation == currentGeneration { isLoading = false; requestTask = nil } }
        do {
            let result = try await withTaskCancellationHandler { try await task.value } onCancel: { task.cancel() }
            try Task.checkCancellation()
            guard generation == currentGeneration, filter == requestedFilter else { return }
            page = result
            cache[requestedFilter] = (result, now())
        } catch {
            guard generation == currentGeneration, !Task.isCancelled, !(error is CancellationError) else { return }
            errorMessage = "We couldn’t refresh these stats. Please try again."
        }
    }

    func loadMore() async {
        guard !isLoading, !isLoadingMore, loadedFilter == filter,
              let current = page, let offset = current.nextOffset else { return }
        let requestedFilter = filter
        let currentGeneration = generation
        isLoadingMore = true
        errorMessage = nil
        let task = Task { try await loader(requestedFilter.period, requestedFilter.providerScope, current.asOf, offset) }
        requestTask = task
        defer { if generation == currentGeneration { isLoadingMore = false; requestTask = nil } }
        do {
            let result = try await withTaskCancellationHandler { try await task.value } onCancel: { task.cancel() }
            try Task.checkCancellation()
            guard generation == currentGeneration, filter == requestedFilter else { return }
            var merged = current
            var knownIDs = Set(current.items.map(\.id))
            merged.items.append(contentsOf: result.items.filter { knownIDs.insert($0.id).inserted })
            merged.nextOffset = result.nextOffset
            page = merged
            // Paging does not extend the lifetime of earlier results.
            cache[requestedFilter] = (merged, cache[requestedFilter]?.fetchedAt ?? now())
        } catch {
            guard generation == currentGeneration, !Task.isCancelled, !(error is CancellationError) else { return }
            errorMessage = "We couldn’t load more results. Try again below."
        }
    }
}
