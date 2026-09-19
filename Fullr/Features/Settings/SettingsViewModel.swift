import Foundation
import Observation

@Observable
final class SettingsViewModel {
    let user: AppUser?
    var notificationsEnabled = true
    var showOnlyStudentVerifiedProviders = true

    var displayName: String { user?.name ?? "Student" }
    var email: String { user?.email ?? "Not signed in" }
    var schoolName: String { user?.schoolName ?? "Add your school" }

    init(user: AppUser?) {
        self.user = user
    }
}
