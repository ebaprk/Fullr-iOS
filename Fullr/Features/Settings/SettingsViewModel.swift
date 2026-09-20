import Foundation
import Observation
import UserNotifications

@MainActor
@Observable
final class SettingsViewModel {
    private let userDefaults: UserDefaults
    private let notificationCenter: UNUserNotificationCenter
    private let pickupRemindersKey = "pickupRemindersEnabled"
    private let studentVerifiedProvidersKey = "showOnlyStudentVerifiedProviders"
    private let pickupReminderIdentifier = "fullr.pickup-reminder.daily"

    let user: AppUser?
    private(set) var pickupRemindersEnabled: Bool
    var showOnlyStudentVerifiedProviders: Bool {
        didSet {
            userDefaults.set(showOnlyStudentVerifiedProviders, forKey: studentVerifiedProvidersKey)
        }
    }
    var pickupReminderMessage: String?

    var displayName: String { user?.name ?? "Student" }
    var email: String { user?.email ?? "Not signed in" }
    var schoolName: String { user?.schoolName ?? "Add your school" }

    init(
        user: AppUser?,
        userDefaults: UserDefaults = .standard,
        notificationCenter: UNUserNotificationCenter = .current()
    ) {
        self.user = user
        self.userDefaults = userDefaults
        self.notificationCenter = notificationCenter
        self.pickupRemindersEnabled = userDefaults.bool(forKey: pickupRemindersKey)
        self.showOnlyStudentVerifiedProviders = userDefaults.bool(forKey: studentVerifiedProvidersKey)
    }

    func setPickupRemindersEnabled(_ isEnabled: Bool) {
        pickupReminderMessage = nil
        if isEnabled {
            Task { await enablePickupReminders() }
        } else {
            disablePickupReminders()
        }
    }

    private func enablePickupReminders() async {
        let isAuthorized: Bool
        do {
            isAuthorized = try await notificationCenter.requestAuthorization(options: [.alert, .sound, .badge])
        } catch {
            isAuthorized = false
        }

        guard isAuthorized else {
            pickupRemindersEnabled = false
            userDefaults.set(false, forKey: pickupRemindersKey)
            pickupReminderMessage = "Turn on notifications in Settings to get pickup reminders."
            return
        }

        pickupRemindersEnabled = true
        userDefaults.set(true, forKey: pickupRemindersKey)
        scheduleDailyPickupReminder()
    }

    private func disablePickupReminders() {
        pickupRemindersEnabled = false
        userDefaults.set(false, forKey: pickupRemindersKey)
        notificationCenter.removePendingNotificationRequests(withIdentifiers: [pickupReminderIdentifier])
    }

    private func scheduleDailyPickupReminder() {
        let content = UNMutableNotificationContent()
        content.title = "Check your pickups"
        content.body = "See what good food is ready near you today."
        content.sound = .default

        var dateComponents = DateComponents()
        dateComponents.hour = 9

        let trigger = UNCalendarNotificationTrigger(dateMatching: dateComponents, repeats: true)
        let request = UNNotificationRequest(identifier: pickupReminderIdentifier, content: content, trigger: trigger)
        notificationCenter.removePendingNotificationRequests(withIdentifiers: [pickupReminderIdentifier])
        notificationCenter.add(request)
    }
}
