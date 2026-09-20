import Foundation
import Observation

@Observable
final class LoginViewModel {
    var firstName = ""
    var lastName = ""
    var email = ""
    var password = ""
    var isCreatingAccount = false
    var didSendConfirmationLink = false

    var primaryButtonTitle: String {
        if didSendConfirmationLink { return "Confirmation Link Sent" }
        return isCreatingAccount ? "Create Account" : "Log In"
    }

    var toggleButtonTitle: String {
        if didSendConfirmationLink { return "Back to Log In" }
        return isCreatingAccount ? "Already have an account? Log in" : "New here? Create an account"
    }

    func resetConfirmation() {
        password = ""
        didSendConfirmationLink = false
        isCreatingAccount = false
    }
}
