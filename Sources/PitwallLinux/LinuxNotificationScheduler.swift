import Foundation
import PitwallShared

/// Backend the Linux shell plugs into at startup. In production this wraps
/// `libnotify` / the `org.freedesktop.Notifications` D-Bus interface; in
/// tests it's a spy that records deliveries without touching the real
/// notification bus.
public protocol LinuxNotificationDelivering: AnyObject {
    func deliver(_ request: NotificationRequest)
}

/// No-op delivery used when the session bus is not reachable (headless or
/// container sessions). The shell must surface the degraded state in its
/// settings UI; it must not pretend a notification was shown.
public final class LinuxNotificationSuppressedBackend: LinuxNotificationDelivering, @unchecked Sendable {
    public init() {}
    public func deliver(_ request: NotificationRequest) {}
}

/// Minimal `NotificationScheduling` adapter for Linux. The scheduling *policy*
/// (dedupe, quiet hours, thresholds) already lives in
/// `PitwallShared.NotificationPolicy` — this type only maps accepted requests
/// onto the platform delivery backend.
public final class LinuxNotificationScheduler: NotificationScheduling, @unchecked Sendable {
    private let backend: LinuxNotificationDelivering
    private let queue = DispatchQueue(label: "pitwall.linux.notifications")
    private var scheduledRequests: [NotificationRequest] = []

    public init(backend: LinuxNotificationDelivering) {
        self.backend = backend
    }

    public func schedule(_ request: NotificationRequest) {
        queue.sync {
            scheduledRequests.append(request)
        }
        backend.deliver(request)
    }

    public func recordedRequests() -> [NotificationRequest] {
        queue.sync { scheduledRequests }
    }
}
