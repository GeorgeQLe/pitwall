import Foundation
import PitwallCore
import PitwallShared

public struct DiagnosticsExporter: Sendable {
    private let eventStore: DiagnosticEventStore
    private let appVersion: @Sendable () -> String
    private let buildNumber: @Sendable () -> String
    private let now: @Sendable () -> Date

    public init(
        eventStore: DiagnosticEventStore = DiagnosticEventStore(),
        appVersion: @escaping @Sendable () -> String = {
            Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "unknown"
        },
        buildNumber: @escaping @Sendable () -> String = {
            Bundle.main.infoDictionary?["CFBundleVersion"] as? String ?? "unknown"
        },
        now: @escaping @Sendable () -> Date = { Date() }
    ) {
        self.eventStore = eventStore
        self.appVersion = appVersion
        self.buildNumber = buildNumber
        self.now = now
    }

    public func export(
        appState: AppProviderState,
        configuration: ProviderConfigurationSnapshot,
        recentEventLimit: Int = 25
    ) async -> DiagnosticsExport {
        DiagnosticsExportBuilder(
            appVersion: appVersion(),
            buildNumber: buildNumber(),
            generatedAt: now(),
            enabledProviderIds: configuration.providerProfiles
                .filter(\.isEnabled)
                .map(\.providerId),
            providerStates: appState.orderedProviders,
            storageHealth: await eventStore.storageHealth(),
            diagnosticEvents: await eventStore.recentEvents(limit: recentEventLimit)
        ).build()
    }
}
