import Foundation
import Observation

@Observable
final class AppViewModel {
    private let authService: AuthServicing
    let offeringService: FoodOfferingServicing
    let statsService: RestaurantStatsServicing

    private(set) var currentUser: AppUser?
    var authErrorMessage: String?
    var isAuthenticating = false
    var isRestoringSession = true

    var isAuthenticated: Bool { currentUser != nil }

    init(authService: AuthServicing? = nil, offeringService: FoodOfferingServicing? = nil, statsService: RestaurantStatsServicing? = nil) {
        let authService = authService ?? SupabaseAuthService()
        self.authService = authService
        self.offeringService = offeringService ?? SupabaseFoodOfferingService(
            sessionProvider: { try await authService.authenticatedSession() }
        )
        self.statsService = statsService ?? SupabaseRestaurantStatsService(
            sessionProvider: { try await authService.authenticatedSession() }
        )
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
    func signUp(firstName: String, lastName: String, email: String, password: String) async -> Bool {
        guard !isAuthenticating else { return false }
        isAuthenticating = true
        isRestoringSession = false
        authErrorMessage = nil
        do {
            if let user = try await authService.signUp(firstName: firstName, lastName: lastName, email: email, password: password) {
                currentUser = user
                isAuthenticating = false
                return false
            }

            isAuthenticating = false
            return true
        } catch {
            authErrorMessage = error.localizedDescription
            isAuthenticating = false
            return false
        }
    }

    func handleAuthCallback(_ url: URL) async {
        do {
            if let user = try await authService.handleAuthCallback(url) {
                currentUser = user
                authErrorMessage = nil
                isRestoringSession = false
            }
        } catch {
            authErrorMessage = error.localizedDescription
            isRestoringSession = false
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
