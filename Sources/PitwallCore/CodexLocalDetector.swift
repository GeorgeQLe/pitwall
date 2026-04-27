import Foundation

public struct CodexLocalDetector: Sendable {
    public init() {}

    public func detect(from snapshot: LocalProviderFileSnapshot) throws -> ProviderState {
        let installDetected = LocalProviderEvidence.hasAnyFile(in: snapshot)
        let configDetected = snapshot.containsFile("config.toml")
        let authDetected = snapshot.containsFile("auth.json")
        let activityDetected = hasActivityEvidence(in: snapshot)
        let rateLimitDetected = hasRateLimitEvidence(in: snapshot)

        guard configDetected else {
            return missingConfigurationState(
                installDetected: installDetected,
                authDetected: authDetected,
                activityDetected: activityDetected,
                rateLimitDetected: rateLimitDetected,
                headline: "Codex configuration missing",
                explanation: "Codex configuration was not found in the injected local evidence snapshot."
            )
        }

        guard authDetected else {
            return missingConfigurationState(
                installDetected: installDetected,
                authDetected: authDetected,
                activityDetected: activityDetected,
                rateLimitDetected: rateLimitDetected,
                headline: "Codex login not detected",
                explanation: "Codex configuration exists, but local CLI auth was not detected. Pitwall does not start ChatGPT OAuth itself; sign in with Codex first, then refresh."
            )
        }

        return ProviderState(
            providerId: .codex,
            displayName: "Codex",
            status: .configured,
            confidence: .estimated,
            headline: "Codex local evidence detected",
            secondaryValue: authDetected ? "CLI auth present" : "CLI auth not detected",
            confidenceExplanation: "Codex configuration and passive local activity are available; exact quota telemetry is not enabled.",
            actions: [
                ProviderAction(kind: .refresh, title: "Scan local evidence"),
                ProviderAction(kind: .openSettings, title: "Open settings")
            ],
            payloads: [
                payload(
                    installDetected: installDetected,
                    authDetected: authDetected,
                    activityDetected: activityDetected,
                    rateLimitDetected: rateLimitDetected
                )
            ]
        )
    }

    private func missingConfigurationState(
        installDetected: Bool,
        authDetected: Bool,
        activityDetected: Bool,
        rateLimitDetected: Bool,
        headline: String,
        explanation: String
    ) -> ProviderState {
        ProviderState(
            providerId: .codex,
            displayName: "Codex",
            status: .missingConfiguration,
            confidence: .observedOnly,
            headline: headline,
            secondaryValue: authDetected ? "CLI auth present" : "CLI auth not detected",
            confidenceExplanation: explanation,
            actions: [
                ProviderAction(kind: .configure, title: "Configure Codex")
            ],
            payloads: [
                payload(
                    installDetected: installDetected,
                    authDetected: authDetected,
                    activityDetected: activityDetected,
                    rateLimitDetected: rateLimitDetected
                )
            ]
        )
    }

    private func payload(
        installDetected: Bool,
        authDetected: Bool,
        activityDetected: Bool,
        rateLimitDetected: Bool
    ) -> ProviderSpecificPayload {
        ProviderSpecificPayload(
            source: "codex-local",
            values: [
                "installDetected": LocalProviderEvidence.flag(installDetected),
                "authDetected": LocalProviderEvidence.flag(authDetected),
                "activityDetected": LocalProviderEvidence.flag(activityDetected),
                "rateLimitDetected": LocalProviderEvidence.flag(rateLimitDetected)
            ]
        )
    }

    private func hasActivityEvidence(in snapshot: LocalProviderFileSnapshot) -> Bool {
        snapshot.containsFile("history.jsonl")
            || snapshot.containsFile { path in
                path.hasPrefix("sessions/") && path.hasSuffix(".jsonl")
            }
    }

    private func hasRateLimitEvidence(in snapshot: LocalProviderFileSnapshot) -> Bool {
        snapshot.files.contains { path, content in
            path.hasPrefix("logs/")
                && LocalProviderEvidence.containsAnyRateLimitHint(in: content)
        }
    }
}
