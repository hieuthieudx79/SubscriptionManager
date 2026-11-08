import Foundation
import UserNotifications

enum ReminderScheduler {
    static func requestPermission() async -> Bool {
        do {
            return try await UNUserNotificationCenter.current()
                .requestAuthorization(options: [.alert, .sound, .badge])
        } catch {
            return false
        }
    }

    static func schedule(for subscription: SubscriptionItem) async {
        let center = UNUserNotificationCenter.current()
        let identifiers = subscription.reminderDays.map {
            "\(subscription.id.uuidString)-\($0)"
        }
        center.removePendingNotificationRequests(withIdentifiers: identifiers)

        guard subscription.isActive else { return }

        for daysBefore in subscription.reminderDays {
            guard let reminderDate = Calendar.current.date(
                byAdding: .day,
                value: -daysBefore,
                to: subscription.renewalDate
            ), reminderDate > .now else {
                continue
            }

            var components = Calendar.current.dateComponents(
                [.year, .month, .day],
                from: reminderDate
            )
            components.hour = 9
            components.minute = 0

            let content = UNMutableNotificationContent()
            content.title = "Upcoming subscription"
            content.body = "\(subscription.appName) renews in \(daysBefore) day(s)."
            content.sound = .default

            let trigger = UNCalendarNotificationTrigger(
                dateMatching: components,
                repeats: false
            )
            let request = UNNotificationRequest(
                identifier: "\(subscription.id.uuidString)-\(daysBefore)",
                content: content,
                trigger: trigger
            )

            do {
                try await center.add(request)
            } catch {
                // A failed local notification does not prevent saving the subscription.
            }
        }
    }

    static func remove(for subscription: SubscriptionItem) {
        let identifiers = subscription.reminderDays.map {
            "\(subscription.id.uuidString)-\($0)"
        }
        UNUserNotificationCenter.current()
            .removePendingNotificationRequests(withIdentifiers: identifiers)
    }
}
