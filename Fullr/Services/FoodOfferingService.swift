import Foundation
import MapKit

protocol FoodOfferingServicing {
    func fetchOfferings(filter: OfferingFilter) async throws -> [FoodOffering]
}

struct MockFoodOfferingService: FoodOfferingServicing {
    func fetchOfferings(filter: OfferingFilter) async throws -> [FoodOffering] {
        sampleOfferings.filter { offering in
            let matchesSearch = filter.searchText.isEmpty || offering.title.localizedStandardContains(filter.searchText) || offering.providerName.localizedStandardContains(filter.searchText)
            let matchesProvider = filter.providerType == nil || offering.providerType == filter.providerType
            let matchesDistance = offering.distanceInMiles <= filter.maximumDistanceInMiles
            let matchesDietary = filter.selectedDietaryTags.isEmpty || filter.selectedDietaryTags.isSubset(of: Set(offering.dietaryTags))
            return matchesSearch && matchesProvider && matchesDistance && matchesDietary
        }
    }

    private var sampleOfferings: [FoodOffering] {
        [
            FoodOffering(id: UUID(), title: "Fresh bagels and spreads", providerName: "Main Street Bagels", providerType: .restaurant, description: "Assorted plain, sesame, and everything bagels with sealed cream cheese tubs.", pickupWindow: "Today, 4:30-6:00 PM", distanceInMiles: 0.4, quantityDescription: "About 24 servings", dietaryTags: [.vegetarian], coordinate: CLLocationCoordinate2D(latitude: 40.7295, longitude: -73.9965), postedAt: Date()),
            FoodOffering(id: UUID(), title: "Pantry produce boxes", providerName: "Campus Community Pantry", providerType: .pantry, description: "Mixed apples, greens, potatoes, and shelf-stable staples packed for student pickup.", pickupWindow: "Today, 2:00-5:00 PM", distanceInMiles: 0.8, quantityDescription: "12 boxes available", dietaryTags: [.vegetarian, .vegan, .glutenFree], coordinate: CLLocationCoordinate2D(latitude: 40.7312, longitude: -73.9912), postedAt: Date()),
            FoodOffering(id: UUID(), title: "Catered rice bowls", providerName: "Union Events Team", providerType: .campus, description: "Leftover individually packed rice bowls from a student org lunch.", pickupWindow: "Today, 1:15-2:15 PM", distanceInMiles: 1.1, quantityDescription: "18 bowls", dietaryTags: [.vegetarian, .halal], coordinate: CLLocationCoordinate2D(latitude: 40.7277, longitude: -73.9951), postedAt: Date()),
            FoodOffering(id: UUID(), title: "Cafe sandwiches", providerName: "Northside Market", providerType: .business, description: "Wrapped sandwiches nearing end-of-day freshness, labeled with ingredients.", pickupWindow: "Tomorrow, 9:00-10:30 AM", distanceInMiles: 2.3, quantityDescription: "30 sandwiches", dietaryTags: [.kosher], coordinate: CLLocationCoordinate2D(latitude: 40.7362, longitude: -73.9890), postedAt: Date())
        ]
    }
}

struct SupabaseFoodOfferingService: FoodOfferingServicing {
    private let client: FullrSupabaseClient?

    init(client: FullrSupabaseClient? = SupabaseClientProvider.makeClient()) {
        self.client = client
    }

    func fetchOfferings(filter: OfferingFilter) async throws -> [FoodOffering] {
        guard let client else {
            throw AuthenticationError.missingSupabaseConfiguration
        }

        let rows = try await fetchRows(client: client)
        return rows
            .compactMap(FoodOffering.init(row:))
            .filter { offering in
                let searchText = filter.searchText.trimmingCharacters(in: .whitespacesAndNewlines)
                let matchesSearch = searchText.isEmpty
                    || offering.title.localizedStandardContains(searchText)
                    || offering.providerName.localizedStandardContains(searchText)
                    || offering.description.localizedStandardContains(searchText)
                let matchesProvider = filter.providerType == nil || offering.providerType == filter.providerType
                let matchesDistance = offering.distanceInMiles <= filter.maximumDistanceInMiles
                let matchesDietary = filter.selectedDietaryTags.isEmpty || filter.selectedDietaryTags.isSubset(of: Set(offering.dietaryTags))
                return matchesSearch && matchesProvider && matchesDistance && matchesDietary
            }
    }

    private func fetchRows(client: FullrSupabaseClient) async throws -> [SupabaseOfferRow] {
        do {
            return try await client.restGet(
                path: "Offers",
                queryItems: activeOfferQueryItems(select: "offer_id,posted_time,offer_end_time,offer_completed,offer_description,store_id,views,Stores(id,name,address,description,store_type)"),
                expecting: [SupabaseOfferRow].self
            )
        } catch {
            let offerRows = try await client.restGet(
                path: "Offers",
                queryItems: activeOfferQueryItems(select: "offer_id,posted_time,offer_end_time,offer_completed,offer_description,store_id,views"),
                expecting: [SupabaseOfferRow].self
            )
            return try await attachStores(to: offerRows, client: client)
        }
    }

    private func activeOfferQueryItems(select: String) -> [URLQueryItem] {
        [
            URLQueryItem(name: "select", value: select),
            URLQueryItem(name: "offer_completed", value: "eq.false"),
            URLQueryItem(name: "offer_end_time", value: "gte.\(Self.supabaseDateFormatter.string(from: Date()))"),
            URLQueryItem(name: "order", value: "offer_end_time.asc"),
            URLQueryItem(name: "limit", value: "75")
        ]
    }

    private func attachStores(to offerRows: [SupabaseOfferRow], client: FullrSupabaseClient) async throws -> [SupabaseOfferRow] {
        let storeIDs = Set(offerRows.map(\.storeID))
        guard !storeIDs.isEmpty else { return offerRows }

        let stores = try await client.restGet(
            path: "Stores",
            queryItems: [
                URLQueryItem(name: "select", value: "id,name,address,description,store_type"),
                URLQueryItem(name: "id", value: "in.(\(storeIDs.map(\.uuidString).joined(separator: ",")))")
            ],
            expecting: [SupabaseStoreRow].self
        )
        let storesByID = Dictionary(uniqueKeysWithValues: stores.map { ($0.id, $0) })

        return offerRows.map { row in
            var row = row
            row.store = storesByID[row.storeID]
            return row
        }
    }

    private static let supabaseDateFormatter: ISO8601DateFormatter = {
        let formatter = ISO8601DateFormatter()
        formatter.formatOptions = [.withInternetDateTime]
        return formatter
    }()
}

private struct SupabaseOfferRow: Decodable {
    let offerID: UUID
    let postedTime: Date
    let offerEndTime: Date
    let offerCompleted: Bool
    let offerDescription: String
    let storeID: UUID
    let views: Int?
    var store: SupabaseStoreRow?

    private enum CodingKeys: String, CodingKey {
        case offerID = "offer_id"
        case postedTime = "posted_time"
        case offerEndTime = "offer_end_time"
        case offerCompleted = "offer_completed"
        case offerDescription = "offer_description"
        case storeID = "store_id"
        case views
        case store = "Stores"
    }
}

private struct SupabaseStoreRow: Decodable {
    let id: UUID
    let name: String
    let address: String
    let description: String?
    let storeType: String

    private enum CodingKeys: String, CodingKey {
        case id
        case name
        case address
        case description
        case storeType = "store_type"
    }
}

private extension FoodOffering {
    init?(row: SupabaseOfferRow) {
        guard !row.offerCompleted, row.offerEndTime > Date(), let store = row.store else {
            return nil
        }

        let offerDescription = row.offerDescription.trimmingCharacters(in: .whitespacesAndNewlines)
        let storeDescription = store.description?.trimmingCharacters(in: .whitespacesAndNewlines)

        self.init(
            id: row.offerID,
            title: offerDescription.isEmpty ? "Food available" : offerDescription,
            providerName: store.name,
            providerType: ProviderType(storeType: store.storeType),
            description: storeDescription?.isEmpty == false ? storeDescription ?? offerDescription : store.address,
            pickupWindow: Self.pickupWindowText(until: row.offerEndTime),
            distanceInMiles: 0,
            quantityDescription: "Available now",
            dietaryTags: [],
            coordinate: CLLocationCoordinate2D(latitude: 40.7306, longitude: -73.9950),
            postedAt: row.postedTime
        )
    }

    private static func pickupWindowText(until endDate: Date) -> String {
        let formatter = DateFormatter()
        formatter.locale = .current
        formatter.timeStyle = .short

        if Calendar.current.isDateInToday(endDate) {
            return "Until \(formatter.string(from: endDate))"
        }

        formatter.dateStyle = .short
        return "Until \(formatter.string(from: endDate))"
    }
}

private extension ProviderType {
    init(storeType: String) {
        let normalizedStoreType = storeType.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()

        if normalizedStoreType.contains("restaurant") || normalizedStoreType.contains("cafe") || normalizedStoreType.contains("dining") {
            self = .restaurant
        } else if normalizedStoreType.contains("pantry") || normalizedStoreType.contains("food bank") {
            self = .pantry
        } else if normalizedStoreType.contains("campus") || normalizedStoreType.contains("school") || normalizedStoreType.contains("university") {
            self = .campus
        } else {
            self = .business
        }
    }
}
