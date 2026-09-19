import Foundation
import Observation

@Observable
final class AppViewModel {
    private let authService: AuthServicing
    let offeringService: FoodOfferingServicing

    private(set) var currentUser: AppUser?
    var authErrorMessage: String?
    var isAuthenticating = false

    var isAuthenticated: Bool { currentUser != nil }

    init(authService: AuthServicing = MockAuthService(), offeringService: FoodOfferingServicing = MockFoodOfferingService()) {
        self.authService = authService
        self.offeringService = offeringService
    }

    func signIn(email: String, password: String) async {
        await authenticate { try await authService.signIn(email: email, password: password) }
    }

    func signUp(name: String, email: String, password: String) async {
        await authenticate { try await authService.signUp(name: name, email: email, password: password) }
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
        authErrorMessage = nil
        do { currentUser = try await action() } catch { authErrorMessage = error.localizedDescription }
        isAuthenticating = false
    }
}
