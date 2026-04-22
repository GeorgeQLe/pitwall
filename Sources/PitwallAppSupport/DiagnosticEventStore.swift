import Foundation
import PitwallCore

public actor DiagnosticEventStore {
    private let userDefaults: UserDefaults
    private let storageKey: String
    private let lastSuccessfulWriteKey: String
    private let redactor: DiagnosticsRedactor
    private let encoder = JSONEncoder()
    private let decoder = JSONDecoder()

    public init(
        userDefaults: UserDefaults = .standard,
        storageKey: String = "pitwall.diagnostic.events.v1",
        lastSuccessfulWriteKey: String = "pitwall.diagnostic.events.lastWrite.v1",
        redactor: DiagnosticsRedactor = DiagnosticsRedactor()
    ) {
        self.userDefaults = userDefaults
        self.storageKey = storageKey
        self.lastSuccessfulWriteKey = lastSuccessfulWriteKey
        self.redactor = redactor
        encoder.dateEncodingStrategy = .iso8601
        decoder.dateDecodingStrategy = .iso8601
    }

    public func load() -> [DiagnosticEvent] {
        guard
            let data = userDefaults.data(forKey: storageKey),
            let events = try? decoder.decode([DiagnosticEvent].self, from: data)
        else {
            return []
        }

        return events
    }

    public func save(_ events: [DiagnosticEvent], now: Date = Date()) throws {
        let redactedEvents = events.map(redactor.redact)
        let data = try encoder.encode(redactedEvents)
        userDefaults.set(data, forKey: storageKey)
        userDefaults.set(now, forKey: lastSuccessfulWriteKey)
    }

    public func append(_ event: DiagnosticEvent, now: Date = Date()) throws {
        var events = load()
        events.append(redactor.redact(event))
        try save(events, now: now)
    }

    public func append(_ events: [DiagnosticEvent], now: Date = Date()) throws {
        guard !events.isEmpty else {
            return
        }

        var stored = load()
        stored.append(contentsOf: events.map(redactor.redact))
        try save(stored, now: now)
    }

    public func recentEvents(limit: Int = 25) -> [DiagnosticEvent] {
        Array(load().sorted { $0.occurredAt > $1.occurredAt }.prefix(limit))
    }

    public func storageHealth() -> StorageHealth {
        StorageHealth(
            status: .healthy,
            lastSuccessfulWriteAt: userDefaults.object(forKey: lastSuccessfulWriteKey) as? Date,
            summary: "Diagnostic events are stored locally after redaction."
        )
    }
}
