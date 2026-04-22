import Foundation
import PitwallShared

/// Backend the Windows shell plugs into at startup. In production this
/// wraps a WinRT `ToastNotificationManager` call; in tests it's a spy that
/// records deliveries without touching the real notification center.
public protocol WindowsToastDelivering: AnyObject {
    func deliver(_ request: NotificationRequest)
}

/// No-op delivery used when WinRT bindings are unavailable. The shell must
/// surface the degraded state in its settings UI; it must not pretend a toast
/// was shown.
public final class WindowsToastSuppressedBackend: WindowsToastDelivering, @unchecked Sendable {
    public init() {}
    public func deliver(_ request: NotificationRequest) {}
}

/// Minimal `NotificationScheduling` adapter for Windows. The scheduling *policy*
/// (dedupe, quiet hours, thresholds) already lives in `PitwallShared.NotificationPolicy`
/// — this type only maps accepted requests onto the platform delivery backend.
public final class WindowsNotificationScheduler: NotificationScheduling, @unchecked Sendable {
    private let backend: WindowsToastDelivering
    private let queue = DispatchQueue(label: "pitwall.windows.notifications")
    private var scheduledRequests: [NotificationRequest] = []

    public init(backend: WindowsToastDelivering) {
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
