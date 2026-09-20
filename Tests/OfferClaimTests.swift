import Foundation

// No live credentials or database are used by these tests.
private final class ClaimURLProtocol: URLProtocol, @unchecked Sendable {
    nonisolated(unsafe) static var handler: ((URLRequest) throws -> (Int, String))?

    nonisolated override class func canInit(with request: URLRequest) -> Bool { true }
    nonisolated override class func canonicalRequest(for request: URLRequest) -> URLRequest { request }
    nonisolated override func startLoading() {
        do {
            let (status, body) = try Self.handler!(request)
            let response = HTTPURLResponse(url: request.url!, statusCode: status, httpVersion: nil, headerFields: ["Content-Type": "application/json"])!
            client?.urlProtocol(self, didReceive: response, cacheStoragePolicy: .notAllowed)
            client?.urlProtocol(self, didLoad: Data(body.utf8))
            client?.urlProtocolDidFinishLoading(self)
        } catch {
            client?.urlProtocol(self, didFailWithError: error)
        }
    }
    nonisolated override func stopLoading() { }
}

@main
struct OfferClaimTests {
    nonisolated private static func requestBody(_ request: URLRequest) throws -> [String: Any] {
        var data = request.httpBody ?? Data()
        if request.httpBody == nil, let stream = request.httpBodyStream {
            stream.open()
            defer { stream.close() }
            var buffer = [UInt8](repeating: 0, count: 1024)
            while stream.hasBytesAvailable {
                let count = stream.read(&buffer, maxLength: buffer.count)
                if count <= 0 { break }
                data.append(contentsOf: buffer.prefix(count))
            }
        }
        return try JSONSerialization.jsonObject(with: data) as! [String: Any]
    }

    static func main() async throws {
        let offerID = UUID()
        let userID = UUID()
        let session = SupabaseStoredSession(accessToken: "user-token", refreshToken: "refresh-token", expiresAt: .distantFuture,
                                            user: SupabaseAuthUser(id: userID, email: nil, userMetadata: [:]))
        let configuration = URLSessionConfiguration.ephemeral
        configuration.protocolClasses = [ClaimURLProtocol.self]
        let client = FullrSupabaseClient(supabaseURL: URL(string: "https://example.invalid")!, anonKey: "public-key",
                                        urlSession: URLSession(configuration: configuration))
        let service = SupabaseFoodOfferingService(client: client, sessionProvider: { session })
        let model = OfferClaimViewModel(offerID: offerID, service: service)

        ClaimURLProtocol.handler = { request in
            precondition(request.httpMethod == "POST")
            precondition(request.value(forHTTPHeaderField: "Authorization") == "Bearer user-token")
            precondition(request.url!.path == "/rest/v1/rpc/get_offer_claim_status")
            let body = try requestBody(request)
            precondition(body["p_offer_id"] as? String == offerID.uuidString)
            precondition(body.count == 1, "The user ID must come from the JWT on the server")
            return (200, "false")
        }
        await model.load()
        precondition(model.hasLoaded && model.claimed == false, "An absent ID means not claimed")

        for claimed in [true, false] {
            ClaimURLProtocol.handler = { request in
                precondition(request.httpMethod == "POST")
                precondition(request.value(forHTTPHeaderField: "Authorization") == "Bearer user-token")
                precondition(request.url!.path == "/rest/v1/rpc/set_offer_claim_status")
                let body = try requestBody(request)
                precondition(body["p_claimed"] as? Bool == claimed)
                precondition(body["p_offer_id"] as? String == offerID.uuidString)
                precondition(body.count == 2, "Do not send a user ID or replace the full array")
                return (200, claimed ? "true" : "false")
            }
            await model.save(claimed)
            precondition(model.claimed == claimed && model.errorMessage == nil)
        }

        ClaimURLProtocol.handler = { _ in (403, "{\"message\":\"Access denied\"}") }
        await model.save(true)
        precondition(model.claimed == false && model.errorMessage != nil && !model.isSaving,
                     "Failed saves must preserve the confirmed answer and allow retry")

        ClaimURLProtocol.handler = { _ in (200, "[]") }
        await model.save(true)
        precondition(model.claimed == false && model.errorMessage != nil, "Empty writes are not success")

        let reopened = OfferClaimViewModel(offerID: offerID, service: service)
        ClaimURLProtocol.handler = { _ in (200, "false") }
        await reopened.load()
        precondition(reopened.hasLoaded && reopened.claimed == false, "Reopening must restore unclaimed status")

        ClaimURLProtocol.handler = { _ in throw URLError(.notConnectedToInternet) }
        await reopened.load()
        precondition(!reopened.hasLoaded && reopened.errorMessage != nil && !reopened.isLoading)

        let unauthenticated = OfferClaimViewModel(offerID: offerID, service: SupabaseFoodOfferingService(client: client))
        ClaimURLProtocol.handler = { _ in preconditionFailure("An anonymous request must not be sent") }
        await unauthenticated.load()
        precondition(!unauthenticated.hasLoaded && unauthenticated.errorMessage != nil)
        await unauthenticated.save(true)
        precondition(unauthenticated.claimed == nil)
        let storeID = UUID()
        let expiredOfferJSON = "{\"offer_id\":\"\(offerID)\",\"store_id\":\"\(storeID)\",\"offer_completed\":true,\"offer_end_time\":\"2020-01-01T00:00:00Z\",\"offer_description\":\"Past pickup\"}"
        ClaimURLProtocol.handler = { request in
            if request.url!.path == "/rest/v1/Stores" {
                return (200, "[{\"id\":\"\(storeID)\",\"name\":\"Test provider\",\"address\":\"Unknown address\"}]")
            }
            precondition(request.httpMethod == "GET" && request.url!.path == "/rest/v1/Offers")
            precondition(request.value(forHTTPHeaderField: "Authorization") == "Bearer user-token")
            let query = URLComponents(url: request.url!, resolvingAgainstBaseURL: false)!.queryItems!
            precondition(query.contains(URLQueryItem(name: "claimed_user_ids", value: "cs.{\(userID.uuidString)}")))
            precondition(!query.contains { $0.name == "offer_completed" || $0.name == "offer_end_time" },
                         "Claimed offers must include past offers")
            return (200, "[\(expiredOfferJSON)]")
        }
        let claimedService = SupabaseFoodOfferingService(
            client: client, geocoder: AddressGeocoder(lookup: { _, _ in nil }), sessionProvider: { session }
        )
        let claimedList = ClaimedOffersViewModel(service: claimedService)
        await claimedList.load()
        precondition(claimedList.offerings.count == 1 && claimedList.offerings[0].id == offerID)
        precondition(!claimedList.offerings[0].hasPickupCoordinate,
                     "A failed address lookup must not hide a claimed offer or show a false map location")

        ClaimURLProtocol.handler = { _ in throw URLError(.notConnectedToInternet) }
        await claimedList.load()
        precondition(claimedList.errorMessage != nil && !claimedList.isLoading)

        ClaimURLProtocol.handler = { _ in (200, "[]") }
        await claimedList.load()
        precondition(claimedList.offerings.isEmpty && claimedList.errorMessage == nil,
                     "Refresh must remove offers that are no longer claimed")

        let pageIDs = (0..<101).map { _ in UUID() }
        ClaimURLProtocol.handler = { request in
            let query = URLComponents(url: request.url!, resolvingAgainstBaseURL: false)!.queryItems!
            let offset = Int(query.first { $0.name == "offset" }!.value!)!
            precondition(offset == 0 || offset == 100)
            let records = pageIDs.dropFirst(offset).prefix(100).map {
                "{\"offer_id\":\"\($0)\",\"store_id\":\"\(storeID)\"}"
            }
            return (200, "[" + records.joined(separator: ",") + "]")
        }
        let allPages = try await client.fetchClaimedOffers(session: session)
        precondition(allPages.map(\.offerID) == pageIDs, "Claimed offers must load beyond the first page")

        let mock = MockFoodOfferingService()
        let available = try await mock.fetchOfferings(filter: OfferingFilter())
        let previewOffer = available[0]
        _ = try await mock.setClaimStatus(true, for: previewOffer.id)
        let previewClaims = try await mock.fetchClaimedOfferings()
        precondition(previewClaims.map(\.id) == [previewOffer.id])
        _ = try await mock.setClaimStatus(false, for: previewOffer.id)
        let clearedClaims = try await mock.fetchClaimedOfferings()
        precondition(clearedClaims.isEmpty)

        ClaimURLProtocol.handler = { request in
            precondition(request.httpMethod == "POST" && request.url!.path == "/rest/v1/rpc/get_provider_claim_stats")
            precondition(request.value(forHTTPHeaderField: "Authorization") == "Bearer user-token")
            let body = try requestBody(request)
            precondition(body["p_days"] as? Int == 7 && body["p_limit"] as? Int == 25 && body["p_offset"] as? Int == 0)
            precondition(body["p_store_id"] == nil && body["user_id"] == nil)
            return (200, "{\"as_of\":\"2020-09-20T00:00:00.125000+00:00\",\"total_claims\":2,\"total_offers\":1,\"total_providers\":1,\"next_offset\":null,\"items\":[{\"id\":\"\(storeID)\",\"name\":\"Restaurant\",\"rank\":1,\"claim_count\":2,\"offer_count\":1}]}")
        }
        let stats: ClaimStatsPage<RestaurantRanking> = try await client.fetchClaimStats(
            request: ClaimStatsRequest(period: .week, storeID: nil, asOf: nil, offset: 0), session: session
        )
        precondition(stats.totalClaims == 2 && stats.items[0].id == storeID && stats.nextOffset == nil)
        print("Offer claim tests passed: authenticated writes, failure recovery, claimed-list filtering, past offers, missing locations, refresh, pagination, and preview claim/unclaim.")
    }
}
