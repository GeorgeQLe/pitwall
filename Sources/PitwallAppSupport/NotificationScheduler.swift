import Foundation

#if canImport(UserNotifications)
import UserNotifications
#endif

#if canImport(UserNotifications)
public final class UserNotificationScheduler: NotificationScheduling {
    private let center: UNUserNotificationCenter
    private let calendar: Calendar

    public init(
        center: UNUserNotificationCenter = .current(),
        calendar: Calendar = .current
    ) {
        self.center = center
        self.calendar = calendar
    }

    public func schedule(_ request: NotificationRequest) {
        center.getNotificationSettings { [center, calendar] settings in
            guard settings.authorizationStatus == .authorized || settings.authorizationStatus == .provisional else {
                return
            }

            let content = UNMutableNotificationContent()
            content.title = request.title
            content.body = request.body
            content.sound = .default

            let trigger: UNNotificationTrigger?
            if let deliverAt = request.deliverAt, deliverAt > request.createdAt {
                trigger = UNCalendarNotificationTrigger(
                    dateMatching: calendar.dateComponents([.year, .month, .day, .hour, .minute, .second], from: deliverAt),
                    repeats: false
                )
            } else {
                trigger = nil
            }

            let notificationRequest = UNNotificationRequest(
                identifier: Self.identifier(for: request),
                content: content,
                trigger: trigger
            )
            center.add(notificationRequest)
        }
    }

    private static func identifier(for request: NotificationRequest) -> String {
        [
            "pitwall",
            request.providerId.rawValue,
            request.kind.rawValue,
            String(Int(request.createdAt.timeIntervalSince1970))
        ].joined(separator: ".")
    }
}
#else
public final class UserNotificationScheduler: NotificationScheduling {
    public init() {}
    public func schedule(_ request: NotificationRequest) {}
}
#endif
