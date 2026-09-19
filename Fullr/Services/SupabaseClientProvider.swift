import Foundation
import Security

enum SupabaseClientProvider {
    nonisolated private static let supabaseURL = "https://akokmwcsjjbzxywojppk.supabase.co"
    nonisolated private static let supabaseAnonKey = "eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6ImFrb2ttd2Nzampienh5d29qcHBrIiwicm9sZSI6ImFub24iLCJpYXQiOjE3ODk4MzA4ODUsImV4cCI6MjEwNTQwNjg4NX0.Zhd3bCIXrGjA4pEB9Rs7Zr5HTgr9JHaS4VV2-W-F5sE"

    nonisolated static func makeClient() -> FullrSupabaseClient? {
        guard
            !supabaseURL.contains("YOUR_PROJECT_REF"),
            !supabaseAnonKey.contains("YOUR_SUPABASE_ANON_KEY"),
            let url = URL(string: supabaseURL)
        else {
            return nil
        }

        return FullrSupabaseClient(supabaseURL: url, anonKey: supabaseAnonKey)
    }
}

struct FullrSupabaseClient {
    let supabaseURL: URL
    let anonKey: String
    private let urlSession: URLSession

    nonisolated init(supabaseURL: URL, anonKey: String, urlSession: URLSession = .shared) {
        self.supabaseURL = supabaseURL
        self.anonKey = anonKey
        self.urlSession = urlSession
    }

    func signIn(email: String, password: String) async throws -> SupabaseAuthResponse {
        var components = authURLComponents(path: "token")
        components.queryItems = [URLQueryItem(name: "grant_type", value: "password")]

        return try await post(
            path: components,
            body: AuthCredentials(email: email, password: password)
        )
    }

    func signUp(name: String, email: String, password: String) async throws -> SupabaseAuthResponse {
        try await post(
            path: authURLComponents(path: "signup"),
            body: SignUpCredentials(email: email, password: password, data: name.isEmpty ? nil : ["name": name])
        )
    }

    func createStudentProfile(id: UUID, name: String, email: String) async throws {
        let nameParts = name.split(separator: " ", maxSplits: 1).map(String.init)
        let profile = StudentProfile(
            studentID: id,
            firstName: nameParts.first ?? "",
            lastName: nameParts.dropFirst().first ?? "",
            email: email
        )

        _ = try await post(
            path: restURLComponents(path: "Student"),
            body: profile,
            prefer: "return=minimal",
            expecting: EmptyResponse.self
        )
    }

    func refreshSession(refreshToken: String) async throws -> SupabaseAuthResponse {
        var components = authURLComponents(path: "token")
        components.queryItems = [URLQueryItem(name: "grant_type", value: "refresh_token")]

        return try await post(
            path: components,
            body: RefreshCredentials(refreshToken: refreshToken)
        )
    }

    func fetchUser(accessToken: String) async throws -> SupabaseAuthUser {
        try await get(
            path: authURLComponents(path: "user"),
            accessToken: accessToken,
            expecting: SupabaseAuthUser.self
        )
    }

    func signOut(accessToken: String?) async throws {
        guard let accessToken else { return }
        _ = try await post(
            path: authURLComponents(path: "logout"),
            body: EmptyBody(),
            accessToken: accessToken,
            expecting: EmptyResponse.self
        )
    }

    func restGet<ResponseBody: Decodable>(
        path: String,
        queryItems: [URLQueryItem],
        expecting responseType: ResponseBody.Type = ResponseBody.self
    ) async throws -> ResponseBody {
        var components = restURLComponents(path: path)
        components.queryItems = queryItems
        return try await get(path: components, accessToken: anonKey, expecting: responseType)
    }

    private func authURLComponents(path: String) -> URLComponents {
        let authURL = supabaseURL.appendingPathComponent("auth").appendingPathComponent("v1").appendingPathComponent(path)
        return URLComponents(url: authURL, resolvingAgainstBaseURL: false) ?? URLComponents()
    }

    private func restURLComponents(path: String) -> URLComponents {
        let restURL = supabaseURL.appendingPathComponent("rest").appendingPathComponent("v1").appendingPathComponent(path)
        return URLComponents(url: restURL, resolvingAgainstBaseURL: false) ?? URLComponents()
    }

    private func post<RequestBody: Encodable, ResponseBody: Decodable>(
        path components: URLComponents,
        body: RequestBody,
        accessToken: String? = nil,
        prefer: String? = nil,
        expecting responseType: ResponseBody.Type = ResponseBody.self
    ) async throws -> ResponseBody {
        guard let url = components.url else {
            throw AuthenticationError.invalidSupabaseURL
        }

        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.setValue(anonKey, forHTTPHeaderField: "apikey")
        request.setValue("Bearer \(accessToken ?? anonKey)", forHTTPHeaderField: "Authorization")
        if let prefer {
            request.setValue(prefer, forHTTPHeaderField: "Prefer")
        }
        request.httpBody = try JSONEncoder().encode(body)

        return try await send(request: request, expecting: responseType)
    }

    private func get<ResponseBody: Decodable>(
        path components: URLComponents,
        accessToken: String,
        expecting responseType: ResponseBody.Type = ResponseBody.self
    ) async throws -> ResponseBody {
        guard let url = components.url else {
            throw AuthenticationError.invalidSupabaseURL
        }

        var request = URLRequest(url: url)
        request.httpMethod = "GET"
        request.setValue(anonKey, forHTTPHeaderField: "apikey")
        request.setValue("Bearer \(accessToken)", forHTTPHeaderField: "Authorization")

        return try await send(request: request, expecting: responseType)
    }

    private func send<ResponseBody: Decodable>(
        request: URLRequest,
        expecting responseType: ResponseBody.Type
    ) async throws -> ResponseBody {
        let (data, response) = try await urlSession.data(for: request)
        guard let httpResponse = response as? HTTPURLResponse else {
            throw AuthenticationError.supabaseRequestFailed("Supabase returned an invalid response.")
        }

        guard 200..<300 ~= httpResponse.statusCode else {
            let message = (try? JSONDecoder().decode(SupabaseErrorResponse.self, from: data).displayMessage) ?? "Supabase request failed."
            throw AuthenticationError.supabaseRequestFailed(message)
        }

        if responseType == EmptyResponse.self {
            return try JSONDecoder().decode(ResponseBody.self, from: Data("{}".utf8))
        }

        return try Self.decoder.decode(ResponseBody.self, from: data)
    }

    private static var decoder: JSONDecoder {
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .custom { decoder in
            let container = try decoder.singleValueContainer()
            let value = try container.decode(String.self)

            if let date = iso8601DateFormatter.date(from: value) ?? fractionalISO8601DateFormatter.date(from: value) {
                return date
            }

            throw DecodingError.dataCorruptedError(
                in: container,
                debugDescription: "Expected an ISO 8601 date, but found \(value)."
            )
        }
        return decoder
    }

    private static let iso8601DateFormatter: ISO8601DateFormatter = {
        let formatter = ISO8601DateFormatter()
        formatter.formatOptions = [.withInternetDateTime]
        return formatter
    }()

    private static let fractionalISO8601DateFormatter: ISO8601DateFormatter = {
        let formatter = ISO8601DateFormatter()
        formatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        return formatter
    }()
}

struct SupabaseStoredSession: Codable {
    let accessToken: String
    let refreshToken: String
    let expiresAt: Date
    let user: SupabaseAuthUser

    var isExpired: Bool {
        expiresAt <= Date().addingTimeInterval(60)
    }
}

struct SupabaseAuthResponse: Decodable {
    let accessToken: String?
    let refreshToken: String?
    let expiresIn: TimeInterval?
    let expiresAt: TimeInterval?
    let user: SupabaseAuthUser

    private enum CodingKeys: String, CodingKey {
        case accessToken = "access_token"
        case refreshToken = "refresh_token"
        case expiresIn = "expires_in"
        case expiresAt = "expires_at"
        case user
    }

    init(from decoder: Decoder) throws {
        if let container = try? decoder.container(keyedBy: CodingKeys.self),
           let nestedUser = try? container.decode(SupabaseAuthUser.self, forKey: .user) {
            accessToken = try container.decodeIfPresent(String.self, forKey: .accessToken)
            refreshToken = try container.decodeIfPresent(String.self, forKey: .refreshToken)
            expiresIn = try container.decodeIfPresent(TimeInterval.self, forKey: .expiresIn)
            expiresAt = try container.decodeIfPresent(TimeInterval.self, forKey: .expiresAt)
            user = nestedUser
        } else {
            accessToken = nil
            refreshToken = nil
            expiresIn = nil
            expiresAt = nil
            user = try SupabaseAuthUser(from: decoder)
        }
    }

    var session: SupabaseStoredSession? {
        guard let accessToken, let refreshToken else { return nil }

        let expirationDate: Date
        if let expiresAt {
            expirationDate = Date(timeIntervalSince1970: expiresAt)
        } else if let expiresIn {
            expirationDate = Date().addingTimeInterval(expiresIn)
        } else {
            expirationDate = Date().addingTimeInterval(3600)
        }

        return SupabaseStoredSession(
            accessToken: accessToken,
            refreshToken: refreshToken,
            expiresAt: expirationDate,
            user: user
        )
    }
}

struct SupabaseAuthUser: Codable {
    let id: UUID
    let email: String?
    let userMetadata: [String: String]

    private enum CodingKeys: String, CodingKey {
        case id
        case email
        case userMetadata = "user_metadata"
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        id = try container.decode(UUID.self, forKey: .id)
        email = try container.decodeIfPresent(String.self, forKey: .email)
        userMetadata = (try? container.decodeIfPresent([String: String].self, forKey: .userMetadata)) ?? [:]
    }
}

private struct AuthCredentials: Encodable {
    let email: String
    let password: String
}

private struct SignUpCredentials: Encodable {
    let email: String
    let password: String
    let data: [String: String]?
}

private struct StudentProfile: Encodable {
    let studentID: UUID
    let firstName: String
    let lastName: String
    let email: String

    private enum CodingKeys: String, CodingKey {
        case studentID = "student_id"
        case firstName = "first_name"
        case lastName = "last_name"
        case email
    }
}

private struct RefreshCredentials: Encodable {
    let refreshToken: String

    private enum CodingKeys: String, CodingKey {
        case refreshToken = "refresh_token"
    }
}

private struct EmptyBody: Encodable { }

private struct EmptyResponse: Decodable { }

private struct SupabaseErrorResponse: Decodable {
    let message: String?
    let errorDescription: String?
    let error: String?
    let msg: String?

    var displayMessage: String {
        message ?? errorDescription ?? msg ?? error ?? "Supabase request failed."
    }

    private enum CodingKeys: String, CodingKey {
        case message
        case errorDescription = "error_description"
        case error
        case msg
    }
}

enum SupabaseSessionStore {
    private static let service = "com.bigba.Fullr.supabase"
    private static let account = "auth-session"

    static func load() throws -> SupabaseStoredSession? {
        var query = baseQuery
        query[kSecReturnData as String] = true
        query[kSecMatchLimit as String] = kSecMatchLimitOne

        var item: CFTypeRef?
        let status = SecItemCopyMatching(query as CFDictionary, &item)

        if status == errSecItemNotFound {
            return nil
        }

        guard status == errSecSuccess, let data = item as? Data else {
            throw AuthenticationError.supabaseRequestFailed("Could not load the saved Supabase session.")
        }

        return try JSONDecoder().decode(SupabaseStoredSession.self, from: data)
    }

    static func save(_ session: SupabaseStoredSession) throws {
        let data = try JSONEncoder().encode(session)
        var query = baseQuery
        query[kSecValueData as String] = data
        query[kSecAttrAccessible as String] = kSecAttrAccessibleAfterFirstUnlockThisDeviceOnly

        let status = SecItemAdd(query as CFDictionary, nil)
        if status == errSecDuplicateItem {
            try update(session)
        } else if status != errSecSuccess {
            throw AuthenticationError.supabaseRequestFailed("Could not save the Supabase session.")
        }
    }

    static func clear() {
        SecItemDelete(baseQuery as CFDictionary)
    }

    private static func update(_ session: SupabaseStoredSession) throws {
        let data = try JSONEncoder().encode(session)
        let attributes = [kSecValueData as String: data]
        let status = SecItemUpdate(baseQuery as CFDictionary, attributes as CFDictionary)

        guard status == errSecSuccess else {
            throw AuthenticationError.supabaseRequestFailed("Could not update the saved Supabase session.")
        }
    }

    private static var baseQuery: [String: Any] {
        [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: account
        ]
    }
}
