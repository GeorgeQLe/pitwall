import Foundation

public struct DiagnosticEvent: Equatable, Sendable, CustomStringConvertible {
    public var providerId: ProviderID?
    public var occurredAt: Date
    public var summary: String
    public var details: [String: String]

    public init(
        providerId: ProviderID? = nil,
        occurredAt: Date,
        summary: String,
        details: [String: String] = [:]
    ) {
        self.providerId = providerId
        self.occurredAt = occurredAt
        self.summary = summary
        self.details = details
    }

    public var description: String {
        [
            "DiagnosticEvent(",
            "providerId: \(providerId?.rawValue ?? "nil"), ",
            "occurredAt: \(occurredAt), ",
            "summary: \(summary), ",
            "details: \(details)",
            ")"
        ].joined()
    }
}

extension DiagnosticEvent: Codable {
    private enum CodingKeys: String, CodingKey {
        case providerId
        case occurredAt
        case summary
        case details
    }

    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        providerId = try container.decodeIfPresent(String.self, forKey: .providerId)
            .map(ProviderID.init(rawValue:))
        occurredAt = try container.decode(Date.self, forKey: .occurredAt)
        summary = try container.decode(String.self, forKey: .summary)
        details = try container.decode([String: String].self, forKey: .details)
    }

    public func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encodeIfPresent(providerId?.rawValue, forKey: .providerId)
        try container.encode(occurredAt, forKey: .occurredAt)
        try container.encode(summary, forKey: .summary)
        try container.encode(details, forKey: .details)
    }
}

public struct StorageHealth: Equatable, Sendable, Codable, CustomStringConvertible {
    public enum Status: String, Equatable, Sendable, Codable {
        case healthy
        case degraded
        case unavailable
    }

    public var status: Status
    public var lastSuccessfulWriteAt: Date?
    public var summary: String?

    public init(
        status: Status,
        lastSuccessfulWriteAt: Date? = nil,
        summary: String? = nil
    ) {
        self.status = status
        self.lastSuccessfulWriteAt = lastSuccessfulWriteAt
        self.summary = summary
    }

    public var description: String {
        [
            "StorageHealth(",
            "status: \(status.rawValue), ",
            "lastSuccessfulWriteAt: \(lastSuccessfulWriteAt?.description ?? "nil"), ",
            "summary: \(summary ?? "nil")",
            ")"
        ].joined()
    }
}

public struct DiagnosticsProviderSummary: Equatable, Sendable, Codable, CustomStringConvertible {
    public var providerId: ProviderID
    public var displayName: String
    public var status: ProviderStatus
    public var confidence: ConfidenceLabel
    public var headline: String
    public var lastUpdatedAt: Date?
    public var confidenceExplanation: String

    public init(
        providerId: ProviderID,
        displayName: String,
        status: ProviderStatus,
        confidence: ConfidenceLabel,
        headline: String,
        lastUpdatedAt: Date? = nil,
        confidenceExplanation: String = ""
    ) {
        self.providerId = providerId
        self.displayName = displayName
        self.status = status
        self.confidence = confidence
        self.headline = headline
        self.lastUpdatedAt = lastUpdatedAt
        self.confidenceExplanation = confidenceExplanation
    }

    public var description: String {
        [
            "DiagnosticsProviderSummary(",
            "providerId: \(providerId.rawValue), ",
            "displayName: \(displayName), ",
            "status: \(status.rawValue), ",
            "confidence: \(confidence.rawValue), ",
            "headline: \(headline), ",
            "lastUpdatedAt: \(lastUpdatedAt?.description ?? "nil"), ",
            "confidenceExplanation: \(confidenceExplanation)",
            ")"
        ].joined()
    }
}

extension DiagnosticsProviderSummary {
    public init(providerState: ProviderState) {
        self.init(
            providerId: providerState.providerId,
            displayName: providerState.displayName,
            status: providerState.status,
            confidence: providerState.confidence,
            headline: providerState.headline,
            lastUpdatedAt: providerState.lastUpdatedAt,
            confidenceExplanation: providerState.confidenceExplanation
        )
    }
}

extension DiagnosticsProviderSummary {
    private enum CodingKeys: String, CodingKey {
        case providerId
        case displayName
        case status
        case confidence
        case headline
        case lastUpdatedAt
        case confidenceExplanation
    }

    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        providerId = ProviderID(rawValue: try container.decode(String.self, forKey: .providerId))
        displayName = try container.decode(String.self, forKey: .displayName)
        status = ProviderStatus(
            rawValue: try container.decode(String.self, forKey: .status)
        ) ?? .degraded
        confidence = ConfidenceLabel(
            rawValue: try container.decode(String.self, forKey: .confidence)
        ) ?? .observedOnly
        headline = try container.decode(String.self, forKey: .headline)
        lastUpdatedAt = try container.decodeIfPresent(Date.self, forKey: .lastUpdatedAt)
        confidenceExplanation = try container.decode(String.self, forKey: .confidenceExplanation)
    }

    public func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(providerId.rawValue, forKey: .providerId)
        try container.encode(displayName, forKey: .displayName)
        try container.encode(status.rawValue, forKey: .status)
        try container.encode(confidence.rawValue, forKey: .confidence)
        try container.encode(headline, forKey: .headline)
        try container.encodeIfPresent(lastUpdatedAt, forKey: .lastUpdatedAt)
        try container.encode(confidenceExplanation, forKey: .confidenceExplanation)
    }
}

public struct DiagnosticsExport: Equatable, Sendable, Codable, CustomStringConvertible {
    public var appVersion: String
    public var buildNumber: String
    public var generatedAt: Date
    public var enabledProviderIds: [ProviderID]
    public var providerSummaries: [DiagnosticsProviderSummary]
    public var storageHealth: StorageHealth
    public var diagnosticEvents: [DiagnosticEvent]

    public init(
        appVersion: String,
        buildNumber: String,
        generatedAt: Date,
        enabledProviderIds: [ProviderID],
        providerSummaries: [DiagnosticsProviderSummary],
        storageHealth: StorageHealth,
        diagnosticEvents: [DiagnosticEvent]
    ) {
        self.appVersion = appVersion
        self.buildNumber = buildNumber
        self.generatedAt = generatedAt
        self.enabledProviderIds = enabledProviderIds
        self.providerSummaries = providerSummaries
        self.storageHealth = storageHealth
        self.diagnosticEvents = diagnosticEvents
    }

    public var description: String {
        [
            "DiagnosticsExport(",
            "appVersion: \(appVersion), ",
            "buildNumber: \(buildNumber), ",
            "generatedAt: \(generatedAt), ",
            "enabledProviderIds: \(enabledProviderIds.map(\.rawValue)), ",
            "providerSummaries: \(providerSummaries), ",
            "storageHealth: \(storageHealth), ",
            "diagnosticEvents: \(diagnosticEvents)",
            ")"
        ].joined()
    }
}

extension DiagnosticsExport {
    private enum CodingKeys: String, CodingKey {
        case appVersion
        case buildNumber
        case generatedAt
        case enabledProviderIds
        case providerSummaries
        case storageHealth
        case diagnosticEvents
    }

    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        appVersion = try container.decode(String.self, forKey: .appVersion)
        buildNumber = try container.decode(String.self, forKey: .buildNumber)
        generatedAt = try container.decode(Date.self, forKey: .generatedAt)
        enabledProviderIds = try container.decode([String].self, forKey: .enabledProviderIds)
            .map(ProviderID.init(rawValue:))
        providerSummaries = try container.decode(
            [DiagnosticsProviderSummary].self,
            forKey: .providerSummaries
        )
        storageHealth = try container.decode(StorageHealth.self, forKey: .storageHealth)
        diagnosticEvents = try container.decode([DiagnosticEvent].self, forKey: .diagnosticEvents)
    }

    public func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(appVersion, forKey: .appVersion)
        try container.encode(buildNumber, forKey: .buildNumber)
        try container.encode(generatedAt, forKey: .generatedAt)
        try container.encode(enabledProviderIds.map(\.rawValue), forKey: .enabledProviderIds)
        try container.encode(providerSummaries, forKey: .providerSummaries)
        try container.encode(storageHealth, forKey: .storageHealth)
        try container.encode(diagnosticEvents, forKey: .diagnosticEvents)
    }
}

public struct DiagnosticsExportBuilder: Sendable {
    public var appVersion: String
    public var buildNumber: String
    public var generatedAt: Date
    public var enabledProviderIds: [ProviderID]
    public var providerStates: [ProviderState]
    public var storageHealth: StorageHealth
    public var diagnosticEvents: [DiagnosticEvent]
    public var redactor: DiagnosticsRedactor

    public init(
        appVersion: String,
        buildNumber: String,
        generatedAt: Date = Date(),
        enabledProviderIds: [ProviderID],
        providerStates: [ProviderState],
        storageHealth: StorageHealth,
        diagnosticEvents: [DiagnosticEvent],
        redactor: DiagnosticsRedactor = DiagnosticsRedactor()
    ) {
        self.appVersion = appVersion
        self.buildNumber = buildNumber
        self.generatedAt = generatedAt
        self.enabledProviderIds = enabledProviderIds
        self.providerStates = providerStates
        self.storageHealth = storageHealth
        self.diagnosticEvents = diagnosticEvents
        self.redactor = redactor
    }

    public func build() -> DiagnosticsExport {
        DiagnosticsExport(
            appVersion: redactor.redactValue(appVersion),
            buildNumber: redactor.redactValue(buildNumber),
            generatedAt: generatedAt,
            enabledProviderIds: enabledProviderIds,
            providerSummaries: providerStates.map { state in
                DiagnosticsProviderSummary(
                    providerId: state.providerId,
                    displayName: state.displayName,
                    status: state.status,
                    confidence: state.confidence,
                    headline: redactor.redactValue(state.headline),
                    lastUpdatedAt: state.lastUpdatedAt,
                    confidenceExplanation: redactor.redactValue(state.confidenceExplanation)
                )
            },
            storageHealth: StorageHealth(
                status: storageHealth.status,
                lastSuccessfulWriteAt: storageHealth.lastSuccessfulWriteAt,
                summary: storageHealth.summary.map(redactor.redactValue)
            ),
            diagnosticEvents: diagnosticEvents.map(redactor.redact)
        )
    }
}

public struct DiagnosticsRedactor: Equatable, Sendable {
    private static let redaction = "[redacted]"

    public init() {}

    public func redact(_ event: DiagnosticEvent) -> DiagnosticEvent {
        DiagnosticEvent(
            providerId: event.providerId,
            occurredAt: event.occurredAt,
            summary: redactValue(event.summary),
            details: event.details.mapValues { value in
                redactValue(value)
            }.redactingSensitiveValues()
        )
    }

    public func redactValue(_ value: String) -> String {
        var redacted = value
        for pattern in sensitiveValuePatterns {
            redacted = redacted.replacingOccurrences(
                of: pattern,
                with: Self.redaction,
                options: [.regularExpression, .caseInsensitive]
            )
        }
        return redacted
    }

    private var sensitiveValuePatterns: [String] {
        [
            #"Bearer\s+[A-Za-z0-9._\-]+"#,
            #"sk-[A-Za-z0-9._\-]+"#,
            #"gh[opsu]_[A-Za-z0-9_]+"#,
            #"tok_[A-Za-z0-9_\-]+"#,
            #"acct_[A-Za-z0-9_\-]+"#,
            #"sessionKey=[A-Za-z0-9._\-]+"#
        ]
    }
}

private extension Dictionary where Key == String, Value == String {
    func redactingSensitiveValues() -> [String: String] {
        reduce(into: [:]) { result, element in
            if element.key.isDiagnosticSecretKey {
                result[element.key] = "[redacted]"
            } else {
                result[element.key] = element.value
            }
        }
    }
}

private extension String {
    var isDiagnosticSecretKey: Bool {
        let normalized = lowercased()
        return [
            "authorization",
            "authheader",
            "cookie",
            "cookies",
            "token",
            "sessionkey",
            "accountid",
            "rawresponse",
            "rawendpointresponse",
            "prompt",
            "completion",
            "modelresponse",
            "modelresponsedata",
            "stdout",
            "source",
            "sourcecontent"
        ].contains { normalized.contains($0) }
    }
}
