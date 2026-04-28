import AppKit
import Foundation
import PitwallAppSupport
import PitwallCore
import Sparkle

@MainActor
final class MenuBarController: NSObject {
    private static let onboardingCompletedKey = "pitwall.onboarding.completed.v1"

    private let formatter = MenuBarStatusFormatter()
    private let pacingCalculator = PacingCalculator()
    private let rotationController = ProviderRotationController()
    private let providerStateFactory = ProviderStateFactory()
    private let popoverController: PopoverController
    private let configurationStore: ProviderConfigurationStore
    private let secretStore: any ProviderSecretStore
    private let claudeSettings: ClaudeAccountSettings
    private let codexAuthController: any CodexAuthControlling
    private let refreshCoordinator: ProviderRefreshCoordinator
    private let phase4SettingsStore: Phase4SettingsStore
    private let providerHistoryStore: ProviderHistoryStore
    private let diagnosticsExporter: DiagnosticsExporter
    private let gitHubTokenManager: GitHubHeatmapTokenManager
    private let gitHubHeatmapCoordinator: GitHubHeatmapCoordinator
    private let notificationScheduler: NotificationScheduling
    private let loginItemService: LoginItemService
    private let onboardingDefaults: UserDefaults
    private let diagnosticEventStore: DiagnosticEventStore
    private let packagingProbe: PackagingProbe
    private let updater: SPUUpdater?
    private var statusItem: NSStatusItem?
    private var rotationTimer: Timer?
    private var reservedStatusItemLength: CGFloat = 0
    private var appState: AppProviderState
    private var preferences: UserPreferences
    private var phase4Settings: Phase4Settings
    private var providerHistorySnapshots: [ProviderHistorySnapshot]
    private var gitHubHeatmap: GitHubHeatmap?
    private var scheduledNotificationKeys: Set<String>

    init(loginItemService: LoginItemService? = nil, updater: SPUUpdater? = nil) {
        let now = Date()
        let configurationStore = ProviderConfigurationStore()
        let secretStore = KeychainSecretStore()
        let providerHistoryStore = ProviderHistoryStore()
        let diagnosticEventStore = DiagnosticEventStore()
        let gitHubTokenManager = GitHubHeatmapTokenManager(secretStore: secretStore)
        let claudeSettings = ClaudeAccountSettings(
            configurationStore: configurationStore,
            secretStore: secretStore
        )
        let codexAuthController = CodexAuthController()

        self.configurationStore = configurationStore
        self.secretStore = secretStore
        self.claudeSettings = claudeSettings
        self.codexAuthController = codexAuthController
        self.phase4SettingsStore = Phase4SettingsStore()
        self.providerHistoryStore = providerHistoryStore
        self.diagnosticEventStore = diagnosticEventStore
        self.diagnosticsExporter = DiagnosticsExporter(eventStore: diagnosticEventStore)
        self.gitHubTokenManager = gitHubTokenManager
        self.gitHubHeatmapCoordinator = GitHubHeatmapCoordinator(tokenManager: gitHubTokenManager)
        self.notificationScheduler = UserNotificationScheduler()
        if let loginItemService {
            self.loginItemService = loginItemService
        } else if #available(macOS 13.0, *) {
            self.loginItemService = SMAppServiceLoginItemService()
        } else {
            self.loginItemService = InMemoryLoginItemService()
        }
        self.refreshCoordinator = ProviderRefreshCoordinator(
            configurationStore: configurationStore,
            secretStore: secretStore,
            codexAuthStatusProvider: codexAuthController,
            codexUsageClient: CodexAppServerUsageClient(),
            historyStore: providerHistoryStore,
            diagnosticEventStore: diagnosticEventStore
        )
        self.onboardingDefaults = .standard
        let appSupportRoot = FileManager.default
            .urls(for: .applicationSupportDirectory, in: .userDomainMask)
            .first?
            .appendingPathComponent("Pitwall", isDirectory: true)
            ?? URL(fileURLWithPath: NSTemporaryDirectory(), isDirectory: true)
                .appendingPathComponent("Pitwall", isDirectory: true)
        self.packagingProbe = PackagingProbe(
            appSupportRoot: appSupportRoot,
            secretStore: KeychainSecretStore(service: "com.pitwall.app.packaging-probe")
        )
        self.updater = updater
        self.appState = ProviderStateFactory().initialAppState(now: now)
        self.preferences = UserPreferences()
        self.phase4Settings = Phase4Settings()
        self.providerHistorySnapshots = []
        self.gitHubHeatmap = nil
        self.scheduledNotificationKeys = []
        self.popoverController = PopoverController()
        super.init()
    }

    func start() {
        let item = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)
        item.button?.target = self
        item.button?.action = #selector(handleStatusItemClick(_:))
        item.button?.sendAction(on: [.leftMouseUp, .rightMouseUp])
        item.button?.image = NSImage(
            systemSymbolName: "gauge.with.dots.needle.67percent",
            accessibilityDescription: "Pitwall"
        )
        item.button?.imagePosition = .imageLeading
        item.button?.toolTip = "Pitwall provider pacing"
        statusItem = item

        applyRotationIfNeeded()
        updateStatusTitle()
        updatePopover()
        startRotationTimer()
        runPackagingProbeIfNeeded()
        loadConfiguration()
    }

    func stop() {
        rotationTimer?.invalidate()
        rotationTimer = nil

        if let statusItem {
            NSStatusBar.system.removeStatusItem(statusItem)
        }
        statusItem = nil
    }

    @objc private func handleStatusItemClick(_ sender: NSStatusBarButton) {
        if NSApp.currentEvent?.type == .rightMouseUp {
            showContextMenu()
            return
        }

        let onboardingPending = !onboardingDefaults.bool(forKey: Self.onboardingCompletedKey)
        if onboardingPending {
            if popoverController.onboardingPanelActive {
                popoverController.dismissOnboardingPanel()
            } else {
                Task {
                    let snapshot = await configurationStore.load()
                    let accounts = (try? await claudeSettings.setupStates()) ?? []
                    presentOnboarding(snapshot: snapshot, claudeAccounts: accounts)
                }
            }
            return
        }

        popoverController.toggle(relativeTo: sender.bounds, of: sender)
    }

    @objc private func refreshNow() {
        Task {
            let outcome = await refreshCoordinator.refreshProviders(trigger: .manual)
            applyRefreshOutcome(outcome)
        }
    }

    @objc private func openSettings() {
        presentSettings()
    }

    @objc private func addAccount() {
        presentSettings()
    }

    @objc private func toggleRotationPause() {
        appState.rotationPaused.toggle()
        preferences.providerRotationMode = appState.rotationPaused ? .paused : .automatic
        updatePopover()
        updateStatusTitle()
    }

    @objc private func clearManualProviderSelection() {
        appState.manualOverrideProviderId = nil
        preferences.providerRotationMode = .automatic
        applyRotationIfNeeded(force: true)
        updatePopover()
        updateStatusTitle()
    }

    @objc private func selectProvider(_ sender: NSMenuItem) {
        guard let providerId = sender.representedObject as? ProviderID else {
            return
        }

        appState.selectedProviderId = providerId
        appState.manualOverrideProviderId = providerId
        appState.lastRotationAt = Date()
        updatePopover()
        updateStatusTitle()
    }

    private func startRotationTimer() {
        rotationTimer?.invalidate()
        rotationTimer = Timer.scheduledTimer(
            withTimeInterval: 1,
            repeats: true
        ) { [weak self] _ in
            Task { @MainActor in
                self?.tickRotation()
            }
        }
    }

    private func tickRotation() {
        let priorProviderId = appState.selectedProviderId
        applyRotationIfNeeded()
        if priorProviderId != appState.selectedProviderId {
            updatePopover()
            updateStatusTitle()
        }
    }

    private func applyRotationIfNeeded(force: Bool = false) {
        let state = force
            ? AppProviderState(
                providers: appState.providers,
                selectedProviderId: nil,
                manualOverrideProviderId: appState.manualOverrideProviderId,
                rotationPaused: appState.rotationPaused,
                lastRotationAt: nil
            )
            : appState

        let decision = rotationController.nextSelection(
            appState: state,
            preferences: preferences,
            now: Date()
        )
        appState.selectedProviderId = decision.selectedProviderId
        appState.lastRotationAt = decision.lastRotationAt
    }

    private func updateStatusTitle() {
        let detail = formatter.format(appState: appState, preferences: preferences)
        let title = formatter.menuBarTitle(appState: appState, preferences: preferences)
        statusItem?.button?.title = title
        statusItem?.button?.toolTip = detail
        reserveStatusItemLength(currentTitle: title)
    }

    private func reserveStatusItemLength(currentTitle: String) {
        guard let statusItem, let button = statusItem.button else {
            return
        }

        let font = button.font ?? NSFont.menuBarFont(ofSize: 0)
        let providerTitles = appState.trackedProviders.map {
            formatter.menuBarTitle(provider: $0, preferences: preferences)
        }
        let candidateTitles = providerTitles + [currentTitle, "Configure"]
        let widestTitle = candidateTitles
            .map { ($0 as NSString).size(withAttributes: [.font: font]).width }
            .max() ?? 0

        let imageWidth = button.image?.size.width ?? 0
        let imagePadding: CGFloat = imageWidth > 0 ? 8 : 0
        let chromePadding: CGFloat = 18
        let targetLength = ceil(widestTitle + imageWidth + imagePadding + chromePadding)

        reservedStatusItemLength = max(reservedStatusItemLength, targetLength)
        statusItem.length = reservedStatusItemLength
    }

    private func updatePopover() {
        popoverController.update(
            appState: appState,
            preferences: preferences,
            historySnapshots: providerHistorySnapshots,
            gitHubHeatmap: gitHubHeatmap,
            gitHubHeatmapSettings: phase4Settings.gitHubHeatmap,
            onRefresh: { [weak self] in self?.refreshNow() },
            onRefreshGitHubHeatmap: { [weak self] in self?.refreshGitHubHeatmap(trigger: .manual) },
            onOpenSettings: { [weak self] in self?.openSettings() },
            onAddAccount: { [weak self] in self?.addAccount() },
            onSelectProvider: { [weak self] providerId in
                self?.appState.selectedProviderId = providerId
                self?.appState.manualOverrideProviderId = providerId
                self?.appState.lastRotationAt = Date()
                self?.updatePopover()
                self?.updateStatusTitle()
            }
        )
    }

    private func runPackagingProbeIfNeeded() {
        let probe = packagingProbe
        let eventStore = diagnosticEventStore
        let defaults = onboardingDefaults
        Task.detached {
            await probe.runOnce(eventStore: eventStore, defaults: defaults)
        }
    }

    private func loadConfiguration(showOnboardingIfNeeded: Bool = true) {
        Task {
            let snapshot = await configurationStore.load()
            let loadedPhase4Settings = await phase4SettingsStore.load()
            let accounts = (try? await claudeSettings.setupStates()) ?? []
            applyConfiguration(
                snapshot: snapshot,
                claudeAccounts: accounts,
                phase4Settings: loadedPhase4Settings
            )
            await reloadProviderHistory()
            let refreshOutcome = await refreshCoordinator.refreshProviders(trigger: .automatic)
            applyRefreshOutcome(refreshOutcome)
            await refreshGitHubHeatmapIfNeeded(trigger: .automatic)

            _ = showOnboardingIfNeeded
            // Onboarding is surfaced via handleStatusItemClick when the flag
            // is unset; auto-presenting during launch races the status item's
            // first layout pass.
        }
    }

    private func presentSettings() {
        Task {
            let snapshot = await configurationStore.load()
            let loadedPhase4Settings = await phase4SettingsStore.load()
            let accounts = (try? await claudeSettings.setupStates()) ?? []
            let codexSetupState = await codexAuthController.status()
            popoverController.showSettings(
                snapshot: snapshot,
                phase4Settings: loadedPhase4Settings,
                claudeAccounts: accounts,
                codexSetupState: codexSetupState,
                onSaveConfiguration: { [weak self] snapshot in
                    await self?.saveConfiguration(snapshot) ?? "Settings controller is unavailable."
                },
                onSavePhase4Settings: { [weak self] settings in
                    await self?.savePhase4Settings(settings) ?? "Settings controller is unavailable."
                },
                onSaveGitHubToken: { [weak self] username, token in
                    await self?.saveGitHubHeatmapToken(username: username, token: token)
                },
                onExportDiagnostics: { [weak self] in
                    await self?.exportDiagnosticsText() ?? "Diagnostics exporter is unavailable."
                },
                onSaveClaudeCredentials: { [weak self] input in
                    await self?.saveClaudeCredentials(input) ?? "Settings controller is unavailable."
                },
                onDeleteClaudeCredentials: { [weak self] accountId in
                    await self?.deleteClaudeCredentials(accountId: accountId) ?? "Settings controller is unavailable."
                },
                onTestClaudeConnection: { [weak self] accountId in
                    await self?.testClaudeConnection(accountId: accountId)
                        ?? .unavailable("Settings controller is unavailable.")
                },
                onStartCodexChatGPTLogin: { [weak self] in
                    await self?.startCodexChatGPTLogin() ?? .idle
                },
                onCurrentCodexChatGPTLoginState: { [weak self] in
                    await self?.currentCodexChatGPTLoginState() ?? .idle
                },
                onRetryCodexChatGPTLoginBrowser: { [weak self] in
                    await self?.retryCodexChatGPTLoginBrowser() ?? .idle
                },
                onCancelCodexChatGPTLogin: { [weak self] in
                    await self?.cancelCodexChatGPTLogin() ?? .idle
                },
                onConnectCodexAPIKey: { [weak self] apiKey in
                    await self?.connectCodexAPIKey(apiKey) ?? .unavailable("Settings controller is unavailable.")
                },
                onDisconnectCodex: { [weak self] in
                    await self?.disconnectCodex() ?? .unavailable("Settings controller is unavailable.")
                },
                onRefreshCodexStatus: { [weak self] in
                    await self?.refreshCodexStatus() ?? CodexSetupState(
                        status: .unavailable,
                        headline: "Settings controller is unavailable.",
                        detail: "Codex status could not be refreshed."
                    )
                },
                onRefresh: { [weak self] in
                    self?.refreshNow()
                },
                loginItemService: loginItemService,
                updater: updater
            )
        }
    }

    private func presentOnboarding(
        snapshot: ProviderConfigurationSnapshot,
        claudeAccounts: [ClaudeAccountSetupState]
    ) {
        guard let button = statusItem?.button else { return }
        Task {
            let codexSetupState = await codexAuthController.status()
            popoverController.presentOnboardingPanel(
                anchoredTo: button,
                snapshot: snapshot,
                claudeAccounts: claudeAccounts,
                codexSetupState: codexSetupState,
                onSaveConfiguration: { [weak self] snapshot in
                    guard let self else { return "Onboarding controller is unavailable." }
                    return await self.saveConfiguration(snapshot)
                },
                onSaveClaudeCredentials: { [weak self] input in
                    guard let self else { return "Onboarding controller is unavailable." }
                    return await self.saveClaudeCredentials(input)
                },
                onTestClaudeConnection: { [weak self] accountId in
                    await self?.testClaudeConnection(accountId: accountId)
                        ?? .unavailable("Onboarding controller is unavailable.")
                },
                onStartCodexChatGPTLogin: { [weak self] in
                    await self?.startCodexChatGPTLogin() ?? .idle
                },
                onCurrentCodexChatGPTLoginState: { [weak self] in
                    await self?.currentCodexChatGPTLoginState() ?? .idle
                },
                onRetryCodexChatGPTLoginBrowser: { [weak self] in
                    await self?.retryCodexChatGPTLoginBrowser() ?? .idle
                },
                onCancelCodexChatGPTLogin: { [weak self] in
                    await self?.cancelCodexChatGPTLogin() ?? .idle
                },
                onConnectCodexAPIKey: { [weak self] apiKey in
                    await self?.connectCodexAPIKey(apiKey) ?? .unavailable("Onboarding controller is unavailable.")
                },
                onDisconnectCodex: { [weak self] in
                    await self?.disconnectCodex() ?? .unavailable("Onboarding controller is unavailable.")
                },
                onRefreshCodexStatus: { [weak self] in
                    await self?.refreshCodexStatus() ?? CodexSetupState(
                        status: .unavailable,
                        headline: "Onboarding controller is unavailable.",
                        detail: "Codex status could not be refreshed."
                    )
                },
                onFinish: { [weak self] in
                    self?.onboardingDefaults.set(true, forKey: Self.onboardingCompletedKey)
                    self?.popoverController.forceDismissOnboardingPanel()
                    self?.loadConfiguration(showOnboardingIfNeeded: false)
                }
            )
        }
    }

    private func saveConfiguration(_ snapshot: ProviderConfigurationSnapshot) async -> String? {
        do {
            try await configurationStore.update { current in
                ProviderConfigurationSnapshot(
                    providerProfiles: providerStateFactory.normalizedProfiles(snapshot.providerProfiles),
                    claudeAccounts: current.claudeAccounts,
                    selectedClaudeAccountId: current.selectedClaudeAccountId,
                    userPreferences: snapshot.userPreferences
                )
            }
            loadConfiguration(showOnboardingIfNeeded: false)
            return nil
        } catch {
            return "Could not save settings: \(error.localizedDescription)"
        }
    }

    private func savePhase4Settings(_ settings: Phase4Settings) async -> String? {
        do {
            try await phase4SettingsStore.save(settings)
            phase4Settings = settings
            preferences.notificationPreferences = settings.notifications
            if !settings.history.isEnabled {
                providerHistorySnapshots = []
                try? await providerHistoryStore.save([])
            } else {
                await reloadProviderHistory()
            }
            await refreshGitHubHeatmapIfNeeded(trigger: .automatic)
            updatePopover()
            return nil
        } catch {
            return "Could not save hardening settings: \(error.localizedDescription)"
        }
    }

    private func saveGitHubHeatmapToken(username: String, token: String) async -> GitHubHeatmapTokenStatus? {
        do {
            let state = try await gitHubTokenManager.saveToken(token, username: username)
            phase4Settings.gitHubHeatmap.username = username
            phase4Settings.gitHubHeatmap.tokenState = state.status
            try await phase4SettingsStore.save(phase4Settings)
            updatePopover()
            return state.status
        } catch {
            return nil
        }
    }

    private func exportDiagnosticsText() async -> String {
        let snapshot = await configurationStore.load()
        let export = await diagnosticsExporter.export(
            appState: appState,
            configuration: snapshot,
            recentEventLimit: phase4Settings.diagnostics.includeRecentEvents ? 25 : 0
        )
        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]

        guard
            let data = try? encoder.encode(export),
            let text = String(data: data, encoding: .utf8)
        else {
            return export.description
        }

        return text
    }

    private func saveClaudeCredentials(_ input: ClaudeCredentialInput) async -> String? {
        do {
            _ = try await claudeSettings.saveCredentials(input)
            loadConfiguration(showOnboardingIfNeeded: false)
            return nil
        } catch {
            return "Could not save Claude credentials: \(error.localizedDescription)"
        }
    }

    private func deleteClaudeCredentials(accountId: String) async -> String? {
        do {
            try await claudeSettings.deleteCredentials(accountId: accountId)
            loadConfiguration(showOnboardingIfNeeded: false)
            return nil
        } catch {
            return "Could not delete Claude credentials: \(error.localizedDescription)"
        }
    }

    private func testClaudeConnection(accountId: String?) async -> ClaudeConnectionTestOutcome {
        let claudeState = await refreshCoordinator.testClaudeConnection(accountId: accountId)
        replaceProviderState(claudeState)
        updatePopover()
        updateStatusTitle()

        switch claudeState.status {
        case .configured:
            return ClaudeConnectionTestOutcome(
                message: "Claude connection succeeded.",
                canContinue: true
            )
        case .expired:
            return ClaudeConnectionTestOutcome(
                message: "Claude auth expired or invalid. Replace the saved credentials.",
                canContinue: false
            )
        case .stale, .degraded:
            return ClaudeConnectionTestOutcome(
                message: "Claude connection could not be verified; showing stale or degraded state.",
                canContinue: true
            )
        case .missingConfiguration:
            return ClaudeConnectionTestOutcome(
                message: "Claude credentials are missing.",
                canContinue: false
            )
        }
    }

    private func startCodexChatGPTLogin() async -> CodexDeviceAuthSessionState {
        await codexAuthController.startChatGPTLogin()
    }

    private func currentCodexChatGPTLoginState() async -> CodexDeviceAuthSessionState {
        let state = await codexAuthController.currentChatGPTLoginState()
        if let finalSetupState = state.finalSetupState {
            let refresh = await refreshCoordinator.refreshProviders(trigger: .manual)
            applyRefreshOutcome(refresh)
            _ = finalSetupState
        }
        return state
    }

    private func retryCodexChatGPTLoginBrowser() async -> CodexDeviceAuthSessionState {
        await codexAuthController.retryOpenChatGPTLoginBrowser()
    }

    private func cancelCodexChatGPTLogin() async -> CodexDeviceAuthSessionState {
        await codexAuthController.cancelChatGPTLogin()
    }

    private func connectCodexAPIKey(_ apiKey: String) async -> CodexConnectionOutcome {
        do {
            let setupState = try await codexAuthController.loginWithAPIKey(apiKey)
            let refresh = await refreshCoordinator.refreshProviders(trigger: .manual)
            applyRefreshOutcome(refresh)
            return CodexConnectionOutcome(
                message: setupState.status == .configured
                    ? "Codex API key connected."
                    : setupState.detail,
                canContinue: setupState.status == .configured,
                setupState: setupState
            )
        } catch {
            return .unavailable("Could not connect Codex API key: \(error.localizedDescription)")
        }
    }

    private func disconnectCodex() async -> CodexConnectionOutcome {
        do {
            let setupState = try await codexAuthController.logout()
            let refresh = await refreshCoordinator.refreshProviders(trigger: .manual)
            applyRefreshOutcome(refresh)
            return CodexConnectionOutcome(
                message: "Codex disconnected locally.",
                canContinue: false,
                setupState: setupState
            )
        } catch {
            return .unavailable("Could not disconnect Codex: \(error.localizedDescription)")
        }
    }

    private func refreshCodexStatus() async -> CodexSetupState {
        let setupState = await codexAuthController.status()
        let refresh = await refreshCoordinator.refreshProviders(trigger: .manual)
        applyRefreshOutcome(refresh)
        return setupState
    }

    private func applyRefreshOutcome(_ outcome: ProviderRefreshOutcome) {
        appState = outcome.appState
        scheduleNotifications(for: appState)
        applyRotationIfNeeded(force: true)
        updatePopover()
        updateStatusTitle()
        Task {
            await reloadProviderHistory()
        }
    }

    private func applyConfiguration(
        snapshot: ProviderConfigurationSnapshot,
        claudeAccounts: [ClaudeAccountSetupState],
        phase4Settings loadedPhase4Settings: Phase4Settings? = nil
    ) {
        preferences = snapshot.userPreferences
        if let loadedPhase4Settings {
            phase4Settings = loadedPhase4Settings
            preferences.notificationPreferences = loadedPhase4Settings.notifications
        }
        appState.providers = providerStateFactory.providers(
            from: snapshot,
            claudeAccounts: claudeAccounts,
            existingProviders: appState.providers
        )
        appState.rotationPaused = preferences.providerRotationMode == .paused
        appState.selectedProviderId = preferences.pinnedProviderId ?? appState.selectedProviderId ?? .claude
        applyRotationIfNeeded(force: true)
        updatePopover()
        updateStatusTitle()
    }

    private func reloadProviderHistory() async {
        guard phase4Settings.history.isEnabled else {
            providerHistorySnapshots = []
            try? await providerHistoryStore.save([])
            updatePopover()
            return
        }

        let snapshots = await providerHistoryStore.load()
        providerHistorySnapshots = ProviderHistoryRetention(
            now: Date(),
            maximumRetentionInterval: phase4Settings.history.maximumRetentionInterval
        ).retainedSnapshots(from: snapshots)
        try? await providerHistoryStore.save(providerHistorySnapshots)
        hydrateClaudeFromHistoryIfNeeded()
        updatePopover()
    }

    private func refreshGitHubHeatmap(trigger: GitHubHeatmapRefreshTrigger) {
        Task {
            await refreshGitHubHeatmapIfNeeded(trigger: trigger)
        }
    }

    private func refreshGitHubHeatmapIfNeeded(trigger: GitHubHeatmapRefreshTrigger) async {
        do {
            let result = try await gitHubHeatmapCoordinator.refresh(
                settings: phase4Settings.gitHubHeatmap,
                trigger: trigger
            )
            phase4Settings.gitHubHeatmap = result.settings
            gitHubHeatmap = result.heatmap ?? gitHubHeatmap
            try? await phase4SettingsStore.save(phase4Settings)
            updatePopover()
        } catch {
            updatePopover()
        }
    }

    private func scheduleNotifications(for appState: AppProviderState) {
        let policy = NotificationPolicy(
            preferences: preferences.notificationPreferences,
            scheduler: notificationScheduler
        )

        for provider in appState.providers {
            if let resetAt = provider.resetWindow?.resetsAt, resetAt > Date() {
                scheduleOnce(
                    key: "reset.\(provider.providerId.rawValue).\(Int(resetAt.timeIntervalSince1970))",
                    policy: policy,
                    event: .reset(providerId: provider.providerId, accountId: nil, resetAt: resetAt)
                )
            }

            if provider.status == .expired {
                scheduleOnce(
                    key: "expired.\(provider.providerId.rawValue)",
                    policy: policy,
                    event: .expiredAuth(providerId: provider.providerId, accountId: nil)
                )
            }

            if provider.status == .degraded || provider.status == .stale {
                scheduleOnce(
                    key: "degraded.\(provider.providerId.rawValue).\(provider.status.rawValue)",
                    policy: policy,
                    event: .telemetryDegraded(
                        providerId: provider.providerId,
                        reason: provider.confidenceExplanation
                    )
                )
            }

            if let weeklyPace = provider.pacingState?.weeklyPace,
               let utilization = provider.pacingState?.weeklyUtilizationPercent {
                scheduleOnce(
                    key: "pacing.\(provider.providerId.rawValue).\(weeklyPace.label.rawValue)",
                    policy: policy,
                    event: .pacingThreshold(
                        providerId: provider.providerId,
                        label: weeklyPace.label,
                        utilizationPercent: utilization
                    )
                )
            }
        }
    }

    private func scheduleOnce(
        key: String,
        policy: NotificationPolicy,
        event: NotificationEvent
    ) {
        guard !scheduledNotificationKeys.contains(key) else {
            return
        }

        scheduledNotificationKeys.insert(key)
        policy.handle(event)
    }

    private func replaceProviderState(_ provider: ProviderState) {
        appState.providers.removeAll { $0.providerId == provider.providerId }
        appState.providers.append(provider)
    }

    private func hydrateClaudeFromHistoryIfNeeded() {
        guard let claudeIndex = appState.providers.firstIndex(where: { $0.providerId == .claude }) else {
            return
        }

        let currentClaude = appState.providers[claudeIndex]
        guard currentClaude.pacingState?.weeklyUtilizationPercent == nil else {
            return
        }

        guard
            currentClaude.status == .configured || currentClaude.status == .stale || currentClaude.status == .degraded,
            let accountId = preferredClaudeAccountId(),
            let latest = providerHistorySnapshots
                .filter({ $0.providerId == .claude && $0.accountId == accountId })
                .max(by: { $0.recordedAt < $1.recordedAt })
        else {
            return
        }

        let resetAt = latest.weeklyResetAt ?? latest.sessionResetAt
        let retainedUsageSnapshots = providerHistorySnapshots
            .filter { $0.providerId == .claude && $0.accountId == accountId }
            .compactMap { snapshot -> UsageSnapshot? in
                guard let weeklyUtilizationPercent = snapshot.weeklyUtilizationPercent else {
                    return nil
                }

                return UsageSnapshot(
                    recordedAt: snapshot.recordedAt,
                    weeklyUtilizationPercent: weeklyUtilizationPercent
                )
            }
            .sorted { $0.recordedAt < $1.recordedAt }
        let dailyBudget = latest.weeklyUtilizationPercent.flatMap { weeklyUtilizationPercent in
            latest.weeklyResetAt.map { weeklyResetAt in
                pacingCalculator.dailyBudget(
                    weeklyUtilizationPercent: weeklyUtilizationPercent,
                    resetAt: weeklyResetAt,
                    now: Date(),
                    retainedSnapshots: retainedUsageSnapshots
                )
            }
        }
        let usageRowsPayload: ProviderSpecificPayload? = {
            var values: [String: String] = [:]
            if let sessionPercent = latest.sessionUtilizationPercent {
                values["Session"] = [
                    String(sessionPercent),
                    latest.sessionResetAt.map { MenuBarStatusFormatter.resetText(
                        resetWindow: ResetWindow(resetsAt: $0),
                        preference: preferences.resetDisplayPreference,
                        now: Date()
                    ) ?? "Unknown reset" } ?? "Unknown reset",
                    latest.confidence.rawValue
                ].joined(separator: "|")
            }
            if let weeklyPercent = latest.weeklyUtilizationPercent {
                values["Weekly"] = [
                    String(weeklyPercent),
                    latest.weeklyResetAt.map { MenuBarStatusFormatter.resetText(
                        resetWindow: ResetWindow(resetsAt: $0),
                        preference: preferences.resetDisplayPreference,
                        now: Date()
                    ) ?? "Unknown reset" } ?? "Unknown reset",
                    latest.confidence.rawValue
                ].joined(separator: "|")
            }

            guard !values.isEmpty else {
                return nil
            }

            return ProviderSpecificPayload(source: "usageRows", values: values)
        }()

        appState.providers[claudeIndex] = ProviderState(
            providerId: currentClaude.providerId,
            displayName: currentClaude.displayName,
            status: .configured,
            confidence: latest.confidence,
            headline: latest.headline,
            primaryValue: latest.weeklyUtilizationPercent.map { Self.formatPercent($0) + " used" } ?? currentClaude.primaryValue,
            secondaryValue: currentClaude.primaryValue ?? currentClaude.secondaryValue,
            resetWindow: ResetWindow(resetsAt: resetAt),
            lastUpdatedAt: latest.recordedAt,
            pacingState: PacingState(
                weeklyUtilizationPercent: latest.weeklyUtilizationPercent,
                dailyBudget: dailyBudget,
                todayUsage: dailyBudget?.todayUsage
            ),
            confidenceExplanation: "Showing the last successful Claude usage snapshot while Pitwall refreshes current data.",
            actions: currentClaude.actions,
            payloads: usageRowsPayload.map { [$0] } ?? currentClaude.payloads
        )
    }

    private func preferredClaudeAccountId() -> String? {
        let claudeAccountIds = appState.providers
        _ = claudeAccountIds
        return providerHistorySnapshots
            .filter { $0.providerId == .claude }
            .max(by: { $0.recordedAt < $1.recordedAt })?
            .accountId
    }

    private static func formatPercent(_ value: Double) -> String {
        let rounded = value.rounded()
        if abs(value - rounded) < 0.05 {
            return "\(Int(rounded))%"
        }

        return String(format: "%.1f%%", value)
    }

    private func showContextMenu() {
        guard let button = statusItem?.button else {
            return
        }

        let menu = NSMenu()
        let titleItem = NSMenuItem(title: formatter.format(appState: appState, preferences: preferences), action: nil, keyEquivalent: "")
        titleItem.isEnabled = false
        menu.addItem(titleItem)
        menu.addItem(.separator())

        menu.addItem(targetedMenuItem(title: "Refresh Now", action: #selector(refreshNow), keyEquivalent: "r", target: self))
        menu.addItem(targetedMenuItem(title: "Open Settings", action: #selector(openSettings), keyEquivalent: ",", target: self))
        menu.addItem(targetedMenuItem(title: appState.rotationPaused ? "Resume Rotation" : "Pause Rotation", action: #selector(toggleRotationPause), keyEquivalent: "p", target: self))
        menu.addItem(targetedMenuItem(title: "Clear Provider Selection", action: #selector(clearManualProviderSelection), keyEquivalent: "", target: self))
        menu.addItem(.separator())

        for provider in appState.trackedProviders {
            let item = NSMenuItem(title: "Show \(provider.displayName)", action: #selector(selectProvider(_:)), keyEquivalent: "")
            item.target = self
            item.representedObject = provider.providerId
            item.state = provider.providerId == appState.selectedProviderId ? .on : .off
            menu.addItem(item)
        }

        menu.addItem(.separator())
        menu.addItem(targetedMenuItem(title: "Quit Pitwall", action: #selector(NSApplication.terminate(_:)), keyEquivalent: "q", target: NSApp))

        statusItem?.menu = menu
        button.performClick(nil)
        statusItem?.menu = nil
    }

    private func targetedMenuItem(title: String, action: Selector, keyEquivalent: String, target: AnyObject) -> NSMenuItem {
        let item = NSMenuItem(title: title, action: action, keyEquivalent: keyEquivalent)
        item.target = target
        return item
    }
}
