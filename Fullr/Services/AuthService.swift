import Foundation

protocol AuthServicing {
    func signIn(email: String, password: String) async throws -> AppUser
    func signUp(name: String, email: String, password: String) async throws -> AppUser
    func signOut() async throws
}

enum AuthenticationError: LocalizedError {
    case missingCredentials

    var errorDescription: String? {
        switch self {
        case .missingCredentials: "Enter an email and password to continue."
        }
    }
}

struct MockAuthService: AuthServicing {
    func signIn(email: String, password: String) async throws -> AppUser {
        try validate(email: email, password: password)
        return AppUser(id: UUID(), name: "Student", email: email, schoolName: "Fullr University")
    }

    func signUp(name: String, email: String, password: String) async throws -> AppUser {
        try validate(email: email, password: password)
        return AppUser(id: UUID(), name: name.isEmpty ? "Student" : name, email: email, schoolName: "Fullr University")
    }

    func signOut() async throws { }

    private func validate(email: String, password: String) throws {
        guard !email.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty, !password.isEmpty else {
            throw AuthenticationError.missingCredentials
        }
    }
}

struct SupabaseAuthService: AuthServicing {
    func signIn(email: String, password: String) async throws -> AppUser {
        try await MockAuthService().signIn(email: email, password: password)
    }

    func signUp(name: String, email: String, password: String) async throws -> AppUser {
        try await MockAuthService().signUp(name: name, email: email, password: password)
    }

    func signOut() async throws {
        try await MockAuthService().signOut()
    }
}
