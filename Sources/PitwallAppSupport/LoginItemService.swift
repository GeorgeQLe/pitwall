import Foundation
#if canImport(ServiceManagement)
import ServiceManagement
#endif

public protocol LoginItemService: AnyObject {
    var isEnabled: Bool { get }
    func setEnabled(_ enabled: Bool) throws
}

public enum LoginItemServiceError: Error, LocalizedError {
    case registrationFailed(underlying: Error)
    case unregistrationFailed(underlying: Error)
    case requiresApproval
    case notFound

    public var errorDescription: String? {
        switch self {
        case .registrationFailed(let error):
            return "Could not enable Launch at Login: \(error.localizedDescription)"
        case .unregistrationFailed(let error):
            return "Could not disable Launch at Login: \(error.localizedDescription)"
        case .requiresApproval:
            return "Launch at Login needs approval in System Settings → General → Login Items."
        case .notFound:
            return "Launch at Login is not available for this build."
        }
    }
}

#if canImport(ServiceManagement)
@available(macOS 13.0, *)
public final class SMAppServiceLoginItemService: LoginItemService {
    private let service: SMAppService

    public init(service: SMAppService = .mainApp) {
        self.service = service
    }

    public var isEnabled: Bool {
        service.status == .enabled
    }

    public func setEnabled(_ enabled: Bool) throws {
        if enabled {
            do {
                try service.register()
            } catch {
                if service.status == .requiresApproval {
                    throw LoginItemServiceError.requiresApproval
                }
                throw LoginItemServiceError.registrationFailed(underlying: error)
            }
        } else {
            do {
                try service.unregister()
            } catch {
                throw LoginItemServiceError.unregistrationFailed(underlying: error)
            }
        }
    }
}
#endif

public final class InMemoryLoginItemService: LoginItemService {
    private var enabled: Bool
    public var setEnabledError: Error?
    public private(set) var setEnabledCallCount = 0

    public init(initiallyEnabled: Bool = false) {
        self.enabled = initiallyEnabled
    }

    public var isEnabled: Bool { enabled }

    public func setEnabled(_ enabled: Bool) throws {
        setEnabledCallCount += 1
        if let error = setEnabledError {
            throw error
        }
        self.enabled = enabled
    }
}
