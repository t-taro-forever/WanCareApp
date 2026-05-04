import Foundation
import UserNotifications

final class LocalNotificationDelegate: NSObject, UNUserNotificationCenterDelegate {
    func userNotificationCenter(
        _ center: UNUserNotificationCenter,
        willPresent notification: UNNotification,
        withCompletionHandler completionHandler: @escaping (UNNotificationPresentationOptions) -> Void
    ) {
        completionHandler([.banner, .list, .sound])
    }
}

@MainActor
enum NotificationManager {
    private static let mealPrefix = "meal-reminder-"
    private static let medicationPrefix = "medication-reminder-"

    static func syncDailyReminders(
        mealSchedules: [MealSchedule],
        medicationSchedules: [MedicationSchedule],
        isPremiumEnabled: Bool
    ) async {
        let center = UNUserNotificationCenter.current()

        guard isPremiumEnabled else {
            await removeAllReminderRequests(center: center)
            return
        }

        let authorized = await requestAuthorizationIfNeeded(center: center)
        guard authorized else { return }

        await removeAllReminderRequests(center: center)

        for schedule in mealSchedules {
            if schedule.notificationEnabled, let components = parseTime(schedule.time) {
                let title = "ごはんの時間です"
                let body = reminderBody(
                    name: schedule.name,
                    content: schedule.content,
                    quantityLabel: "量",
                    quantityValue: schedule.amount
                )
                let id = mealPrefix + schedule.id.uuidString
                await addDailyNotification(center: center, id: id, title: title, body: body, components: components)
            }
        }

        for schedule in medicationSchedules {
            if schedule.notificationEnabled, let components = parseTime(schedule.time) {
                let title = "お薬の時間です"
                let body = reminderBody(
                    name: schedule.name,
                    content: schedule.content,
                    quantityLabel: "用量",
                    quantityValue: schedule.dose
                )
                let id = medicationPrefix + schedule.id.uuidString
                await addDailyNotification(center: center, id: id, title: title, body: body, components: components)
            }
        }
    }

    private static func requestAuthorizationIfNeeded(center: UNUserNotificationCenter) async -> Bool {
        let settings = await center.notificationSettings()

        if settings.authorizationStatus == .authorized || settings.authorizationStatus == .provisional {
            return true
        }

        if settings.authorizationStatus == .denied {
            return false
        }

        do {
            return try await center.requestAuthorization(options: [.alert, .badge, .sound])
        } catch {
            return false
        }
    }

    private static func removeAllReminderRequests(center: UNUserNotificationCenter) async {
        let requests = await center.pendingNotificationRequests()
        let ids = requests
            .map(\.identifier)
            .filter { $0.hasPrefix(mealPrefix) || $0.hasPrefix(medicationPrefix) }
        if !ids.isEmpty {
            center.removePendingNotificationRequests(withIdentifiers: ids)
        }
    }

    private static func addDailyNotification(
        center: UNUserNotificationCenter,
        id: String,
        title: String,
        body: String,
        components: DateComponents
    ) async {
        let content = UNMutableNotificationContent()
        content.title = title
        content.body = body
        content.sound = .default

        let trigger = UNCalendarNotificationTrigger(dateMatching: components, repeats: true)
        let request = UNNotificationRequest(identifier: id, content: content, trigger: trigger)

        do {
            try await center.add(request)
        } catch {
            // Ignore a single schedule registration failure and continue.
        }
    }

    private static func parseTime(_ value: String) -> DateComponents? {
        let parts = value.split(separator: ":")
        guard parts.count == 2,
              let hour = Int(parts[0]),
              let minute = Int(parts[1]),
              (0...23).contains(hour),
              (0...59).contains(minute)
        else {
            return nil
        }

        var components = DateComponents()
        components.hour = hour
        components.minute = minute
        return components
    }

    private static func reminderBody(
        name: String,
        content: String,
        quantityLabel: String,
        quantityValue: String
    ) -> String {
        var lines: [String] = []
        let normalizedName = normalize(name)
        let normalizedContent = normalize(content)
        let normalizedQuantity = normalize(quantityValue)

        if !normalizedName.isEmpty {
            lines.append(normalizedName)
        }
        if !normalizedContent.isEmpty {
            lines.append("内容: \(normalizedContent)")
        }
        if !normalizedQuantity.isEmpty {
            lines.append("\(quantityLabel): \(normalizedQuantity)")
        }

        return lines.joined(separator: " / ")
    }

    private static func normalize(_ value: String) -> String {
        value.trimmingCharacters(in: .whitespacesAndNewlines)
    }
}
