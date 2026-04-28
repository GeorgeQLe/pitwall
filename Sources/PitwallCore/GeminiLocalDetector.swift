import Foundation

public struct GeminiLocalDetector: Sendable {
    public init() {}

    public func detect(from snapshot: LocalProviderFileSnapshot) throws -> ProviderState {
        let installDetected = LocalProviderEvidence.hasAnyFile(in: snapshot)
        let settingsContent = snapshot.files["settings.json"]
        let configDetected = settingsContent != nil
        let authDetected = snapshot.containsFile("oauth_creds.json")
        let activityContent = firstChatSessionContent(in: snapshot)
        let activityDetected = activityContent != nil
        let settingsMetadata = sanitizedSettingsMetadata(from: settingsContent)
        let tokenCountObserved = activityContent.flatMap(Self.tokenCountObserved)

        guard configDetected else {
            return missingConfigurationState(
                installDetected: installDetected,
                authDetected: authDetected,
                activityDetected: activityDetected,
                tokenCountObserved: tokenCountObserved,
                settingsMetadata: settingsMetadata
            )
        }

        return ProviderState(
            providerId: .gemini,
            displayName: "Gemini",
            status: .configured,
            confidence: .estimated,
            headline: "Gemini local evidence detected",
            secondaryValue: authDetected ? "CLI auth present" : "CLI auth not detected",
            confidenceExplanation: "Gemini configuration and passive local activity are available; exact quota telemetry is not enabled.",
            actions: [
                ProviderAction(kind: .refresh, title: "Scan local evidence"),
                ProviderAction(kind: .openSettings, title: "Open settings")
            ],
            payloads: [
                payload(
                    installDetected: installDetected,
                    authDetected: authDetected,
                    activityDetected: activityDetected,
                    tokenCountObserved: tokenCountObserved,
                    settingsMetadata: settingsMetadata
                )
            ]
        )
    }

    private func missingConfigurationState(
        installDetected: Bool,
        authDetected: Bool,
        activityDetected: Bool,
        tokenCountObserved: Int?,
        settingsMetadata: [String: String]
    ) -> ProviderState {
        ProviderState(
            providerId: .gemini,
            displayName: "Gemini",
            status: .missingConfiguration,
            confidence: .observedOnly,
            headline: "Gemini configuration missing",
            confidenceExplanation: "Gemini settings were not found in the injected local evidence snapshot.",
            actions: [
                ProviderAction(kind: .configure, title: "Configure Gemini")
            ],
            payloads: [
                payload(
                    installDetected: installDetected,
                    authDetected: authDetected,
                    activityDetected: activityDetected,
                    tokenCountObserved: tokenCountObserved,
                    settingsMetadata: settingsMetadata
                )
            ]
        )
    }

    private func payload(
        installDetected: Bool,
        authDetected: Bool,
        activityDetected: Bool,
        tokenCountObserved: Int?,
        settingsMetadata: [String: String]
    ) -> ProviderSpecificPayload {
        var values = [
            "installDetected": LocalProviderEvidence.flag(installDetected),
            "authDetected": LocalProviderEvidence.flag(authDetected),
            "activityDetected": LocalProviderEvidence.flag(activityDetected)
        ]

        if let tokenCountObserved {
            values["tokenCountObserved"] = String(tokenCountObserved)
        }

        values.merge(settingsMetadata) { current, _ in current }

        return ProviderSpecificPayload(
            source: "gemini-local",
            values: values
        )
    }

    private func firstChatSessionContent(in snapshot: LocalProviderFileSnapshot) -> String? {
        snapshot.firstFileContent { path in
            path.hasPrefix("tmp/")
                && path.contains("/chats/")
                && path.hasSuffix(".json")
                && path.split(separator: "/").last?.hasPrefix("session-") == true
        }
    }

    private func sanitizedSettingsMetadata(from content: String?) -> [String: String] {
        guard
            let content,
            let data = content.data(using: .utf8),
            let object = try? JSONSerialization.jsonObject(with: data) as? [String: Any]
        else {
            return [:]
        }

        var values: [String: String] = [:]
        if let selectedAuthType = Self.selectedAuthType(from: object) {
            values["authMode"] = selectedAuthType
        }
        if let profile = object["profile"] as? String {
            values["profile"] = profile
        }
        return values
    }

    private static func selectedAuthType(from object: [String: Any]) -> String? {
        if let selectedAuthType = object["selectedAuthType"] as? String {
            return selectedAuthType
        }

        return ((object["security"] as? [String: Any])?["auth"] as? [String: Any])?["selectedType"] as? String
    }

    private static func tokenCountObserved(from content: String) -> Int? {
        guard
            let data = content.data(using: .utf8),
            let object = try? JSONSerialization.jsonObject(with: data) as? [String: Any]
        else {
            return nil
        }

        if let tokenCount = object["tokenCount"] as? Int {
            return tokenCount
        }
        if let tokenCount = object["tokenCount"] as? Double {
            return Int(tokenCount)
        }
        return nil
    }
}
