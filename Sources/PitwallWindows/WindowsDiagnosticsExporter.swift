import Foundation
import PitwallCore
import PitwallShared

public struct WindowsDiagnosticsInput: Sendable {
    public var appVersion: String
    public var buildNumber: String
    public var enabledProviderIds: [ProviderID]
    public var providerStates: [ProviderState]
    public var storageHealth: StorageHealth
    public var diagnosticEvents: [DiagnosticEvent]

    public init(
        appVersion: String,
        buildNumber: String,
        enabledProviderIds: [ProviderID],
        providerStates: [ProviderState],
        storageHealth: StorageHealth,
        diagnosticEvents: [DiagnosticEvent]
    ) {
        self.appVersion = appVersion
        self.buildNumber = buildNumber
        self.enabledProviderIds = enabledProviderIds
        self.providerStates = providerStates
        self.storageHealth = storageHealth
        self.diagnosticEvents = diagnosticEvents
    }
}

public struct WindowsDiagnosticsExporter: Sendable {
    public static let defaultFileName = "pitwall-diagnostics.json"

    private let root: WindowsStorageRoot
    private let fileName: String
    private let now: @Sendable () -> Date
    private let redactor: DiagnosticsRedactor

    public init(
        root: WindowsStorageRoot,
        fileName: String = defaultFileName,
        redactor: DiagnosticsRedactor = DiagnosticsRedactor(),
        now: @escaping @Sendable () -> Date = { Date() }
    ) {
        self.root = root
        self.fileName = fileName
        self.now = now
        self.redactor = redactor
    }

    public func build(input: WindowsDiagnosticsInput) -> DiagnosticsExport {
        DiagnosticsExportBuilder(
            appVersion: input.appVersion,
            buildNumber: input.buildNumber,
            generatedAt: now(),
            enabledProviderIds: input.enabledProviderIds,
            providerStates: input.providerStates,
            storageHealth: input.storageHealth,
            diagnosticEvents: input.diagnosticEvents,
            redactor: redactor
        ).build()
    }

    @discardableResult
    public func export(input: WindowsDiagnosticsInput) throws -> URL {
        let export = build(input: input)
        try root.ensureDirectoryExists()

        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        let data = try encoder.encode(export)

        let url = root.fileURL(for: fileName)
        try data.write(to: url, options: [.atomic])
        return url
    }
}
