import Foundation
import PitwallCore

extension ProviderState {
    public var sessionUtilizationPercent: Double? {
        if let claudeSessionPercent = usageRowPercent(named: "Session") {
            return claudeSessionPercent
        }

        guard providerId == .codex,
              let payload = payloads.first(where: { $0.source == "codex-rate-limits" }),
              let encodedValue = payload.values["primary"] else {
            return nil
        }

        let parts = encodedValue.split(separator: "|", omittingEmptySubsequences: false)
        guard let percentPart = parts.first else {
            return nil
        }

        return Double(percentPart)
    }

    private func usageRowPercent(named label: String) -> Double? {
        guard let payload = payloads.first(where: { $0.source == "usageRows" }),
              let encodedValue = payload.values[label] else {
            return nil
        }

        let parts = encodedValue.split(separator: "|", omittingEmptySubsequences: false)
        guard let percentPart = parts.first, let percent = Double(percentPart) else {
            return nil
        }

        return percent
    }
}
