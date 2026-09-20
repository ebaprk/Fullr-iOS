import Foundation

enum StatsProviderScope: String, CaseIterable, Identifiable {
    case all = "", restaurant = "Restaurant", business = "Business", pantry = "Pantry", campus = "Campus"
    var id: String { rawValue }
    var title: String {
        switch self {
        case .all: "All providers"
        case .restaurant: "Restaurants"
        case .business: "Businesses"
        case .pantry: "Pantries"
        case .campus: "Campus"
        }
    }
}

struct StatsFilter: Hashable {
    let period: StatsPeriod
    let providerScope: StatsProviderScope
}

enum StatsPeriod: Int, CaseIterable, Identifiable {
    case week = 7, month = 30, quarter = 90, allTime = 0
    var id: Int { rawValue }
    var title: String {
        switch self {
        case .week: "7 days"
        case .month: "30 days"
        case .quarter: "90 days"
        case .allTime: "All time"
        }
    }
    var explanation: String {
        self == .allTime ? "Current claims on all posted offers." : "Current claims on offers posted in the last \(rawValue) days."
    }
}

struct RestaurantRanking: Decodable, Identifiable, Hashable {
    let id: UUID
    let name: String
    let rank: Int
    let claimCount: Int
    let offerCount: Int
    var providerType: String? = nil

    enum CodingKeys: String, CodingKey {
        case id, name, rank
        case claimCount = "claim_count"
        case offerCount = "offer_count"
        case providerType = "provider_type"
    }
}

struct RestaurantOfferStats: Decodable, Identifiable {
    let id: UUID
    let name: String
    let postedAt: Date?
    let claimCount: Int

    enum CodingKeys: String, CodingKey {
        case id, name
        case postedAt = "posted_at"
        case claimCount = "claim_count"
    }
}

struct ClaimStatsPage<Row: Decodable & Identifiable>: Decodable {
    let asOf: Date
    let totalClaims: Int
    let totalOffers: Int
    let totalProviders: Int
    var items: [Row]
    var nextOffset: Int?

    enum CodingKeys: String, CodingKey {
        case asOf = "as_of"
        case totalClaims = "total_claims"
        case totalOffers = "total_offers"
        case totalProviders = "total_providers"
        case items
        case nextOffset = "next_offset"
    }
}

struct ClaimStatsRequest: Encodable {
    let period: StatsPeriod
    let storeID: UUID?
    let asOf: Date?
    let offset: Int
    var providerScope: StatsProviderScope = .all
    static let pageSize = 25

    enum CodingKeys: String, CodingKey {
        case days = "p_days", storeID = "p_store_id", asOf = "p_as_of"
        case limit = "p_limit", offset = "p_offset"
        case providerType = "p_provider_type"
    }

    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(period.rawValue, forKey: .days)
        try container.encodeIfPresent(storeID, forKey: .storeID)
        if let asOf {
            let formatter = ISO8601DateFormatter()
            formatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
            try container.encode(formatter.string(from: asOf), forKey: .asOf)
        }
        try container.encode(Self.pageSize, forKey: .limit)
        try container.encode(offset, forKey: .offset)
        if providerScope != .all { try container.encode(providerScope.rawValue, forKey: .providerType) }
    }
}
