import Foundation
import Observation

@Observable
final class LoginViewModel {
    var name = ""
    var email = ""
    var password = ""
    var isCreatingAccount = false

    var primaryButtonTitle: String { isCreatingAccount ? "Create Account" : "Log In" }
}
