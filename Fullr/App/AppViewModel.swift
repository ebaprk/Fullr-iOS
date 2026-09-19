import Foundation
import Observation

@Observable
final class AppViewModel {
    private let authService: AuthServicing
    let offeringService: FoodOfferingServicing

    private(set) var currentUser: AppUser?
    var authErrorMessage: String?
    var isAuthenticating = false
    var isRestoringSession = true

    var isAuthenticated: Bool { currentUser != nil }

    init(authService: AuthServicing? = nil, offeringService: FoodOfferingServicing = SupabaseFoodOfferingService()) {
        self.authService = authService ?? SupabaseAuthService()
        self.offeringService = offeringService
    }

    func restoreSession() async {
        isRestoringSession = true
        authErrorMessage = nil
        do {
            currentUser = try await authService.restoreSession()
        } catch {
            currentUser = nil
            authErrorMessage = error.localizedDescription
        }
        isRestoringSession = false
    }

    func signIn(email: String, password: String) async {
        await authenticate { try await authService.signIn(email: email, password: password) }
    }

    @discardableResult
    func signUp(name: String, email: String, password: String) async -> Bool {
        guard !isAuthenticating else { return false }
        isAuthenticating = true
        isRestoringSession = false
        authErrorMessage = nil
        do {
            try await authService.signUp(name: name, email: email, password: password)
            isAuthenticating = false
            return true
        } catch {
            authErrorMessage = error.localizedDescription
            isAuthenticating = false
            return false
        }
    }

    func signOut() async {
        do {
            try await authService.signOut()
            currentUser = nil
            authErrorMessage = nil
        } catch {
            authErrorMessage = error.localizedDescription
        }
    }

    private func authenticate(action: () async throws -> AppUser) async {
        guard !isAuthenticating else { return }
        isAuthenticating = true
        isRestoringSession = false
        authErrorMessage = nil
        do { currentUser = try await action() } catch { authErrorMessage = error.localizedDescription }
        isAuthenticating = false
    }
}
