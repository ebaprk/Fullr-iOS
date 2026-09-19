import Foundation

protocol AuthServicing {
    func restoreSession() async throws -> AppUser?
    func signIn(email: String, password: String) async throws -> AppUser
    func signUp(name: String, email: String, password: String) async throws
    func signOut() async throws
}

enum AuthenticationError: LocalizedError {
    case missingCredentials
    case missingSupabaseConfiguration
    case invalidSupabaseURL
    case supabaseRequestFailed(String)
    case emailConfirmationRequired(String)
    case invalidEducationEmail

    var errorDescription: String? {
        switch self {
        case .missingCredentials: "Enter an email and password to continue."
        case .missingSupabaseConfiguration: "Add your Supabase URL and anon key in SupabaseClientProvider.swift."
        case .invalidSupabaseURL: "The Supabase URL is invalid."
        case .supabaseRequestFailed(let message): message
        case .emailConfirmationRequired(let email): "Check \(email) to confirm your account before logging in."
        case .invalidEducationEmail: "Use a valid .edu email address to create an account."
        }
    }
}

struct MockAuthService: AuthServicing {
    func restoreSession() async throws -> AppUser? {
        nil
    }

    func signIn(email: String, password: String) async throws -> AppUser {
        try validate(email: email, password: password)
        return AppUser(id: UUID(), name: "Student", email: email, schoolName: "Fullr University")
    }

    func signUp(name: String, email: String, password: String) async throws {
        try validate(email: email, password: password)
        try validateEducationEmail(email)
    }

    func signOut() async throws { }

    private func validate(email: String, password: String) throws {
        guard !email.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty, !password.isEmpty else {
            throw AuthenticationError.missingCredentials
        }
    }

    private func validateEducationEmail(_ email: String) throws {
        guard email.trimmingCharacters(in: .whitespacesAndNewlines).lowercased().hasSuffix(".edu") else {
            throw AuthenticationError.invalidEducationEmail
        }
    }
}

@MainActor
final class SupabaseAuthService: AuthServicing {
    private let client: FullrSupabaseClient?
    private var session: SupabaseStoredSession?

    init(client: FullrSupabaseClient? = SupabaseClientProvider.makeClient()) {
        self.client = client
    }

    func restoreSession() async throws -> AppUser? {
        guard var storedSession = try SupabaseSessionStore.load() else { return nil }

        if storedSession.isExpired {
            let response = try await configuredClient.refreshSession(refreshToken: storedSession.refreshToken)
            guard let refreshedSession = response.session else {
                SupabaseSessionStore.clear()
                return nil
            }
            storedSession = refreshedSession
        } else {
            let user = try await configuredClient.fetchUser(accessToken: storedSession.accessToken)
            storedSession = SupabaseStoredSession(
                accessToken: storedSession.accessToken,
                refreshToken: storedSession.refreshToken,
                expiresAt: storedSession.expiresAt,
                user: user
            )
        }

        try SupabaseSessionStore.save(storedSession)
        session = storedSession
        return AppUser(user: storedSession.user)
    }

    func signIn(email: String, password: String) async throws -> AppUser {
        try validate(email: email, password: password)
        let response = try await configuredClient.signIn(email: email.trimmingCharacters(in: .whitespacesAndNewlines), password: password)
        guard let storedSession = response.session else {
            throw AuthenticationError.supabaseRequestFailed("Supabase did not return a session.")
        }

        try SupabaseSessionStore.save(storedSession)
        session = storedSession
        return AppUser(user: response.user)
    }

    func signUp(name: String, email: String, password: String) async throws {
        try validate(email: email, password: password)
        let trimmedEmail = email.trimmingCharacters(in: .whitespacesAndNewlines)
        let trimmedName = name.trimmingCharacters(in: .whitespacesAndNewlines)
        try validateEducationEmail(trimmedEmail)
        let response = try await configuredClient.signUp(name: trimmedName, email: trimmedEmail, password: password)
        try await configuredClient.createStudentProfile(id: response.user.id, name: trimmedName, email: trimmedEmail)
    }

    func signOut() async throws {
        try await configuredClient.signOut(accessToken: session?.accessToken)
        SupabaseSessionStore.clear()
        session = nil
    }

    private var configuredClient: FullrSupabaseClient {
        get throws {
            guard let client else { throw AuthenticationError.missingSupabaseConfiguration }
            return client
        }
    }

    private func validate(email: String, password: String) throws {
        guard !email.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty, !password.isEmpty else {
            throw AuthenticationError.missingCredentials
        }
    }

    private func validateEducationEmail(_ email: String) throws {
        guard email.lowercased().hasSuffix(".edu") else {
            throw AuthenticationError.invalidEducationEmail
        }
    }
}

private extension AppUser {
    init(user: SupabaseAuthUser) {
        let displayName = user.userMetadata["name"]?.trimmingCharacters(in: .whitespacesAndNewlines)
        let email = user.email ?? ""
        let name = displayName?.isEmpty == false ? displayName ?? email : email

        self.init(
            id: user.id,
            name: name,
            email: email,
            schoolName: nil
        )
    }
}
