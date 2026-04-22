import AppKit
import Foundation
import PitwallAppSupport
import PitwallCore

@MainActor
final class MenuBarController: NSObject {
    private static let onboardingCompletedKey = "pitwall.onboarding.completed.v1"

    private let formatter = MenuBarStatusFormatter()
    private let rotationController = ProviderRotationController()
    private let providerStateFactory = ProviderStateFactory()
    private let popoverController: PopoverController
    private let configurationStore: ProviderConfigurationStore
    private let secretStore: any ProviderSecretStore
    private let claudeSettings: ClaudeAccountSettings
    private let refreshCoordinator: ProviderRefreshCoordinator
    private let onboardingDefaults: UserDefaults
    private var statusItem: NSStatusItem?
    private var rotationTimer: Timer?
    private var appState: AppProviderState
    private var preferences: UserPreferences

    override init() {
        let now = Date()
        let configurationStore = ProviderConfigurationStore()
        let secretStore = KeychainSecretStore()
        let claudeSettings = ClaudeAccountSettings(
            configurationStore: configurationStore,
            secretStore: secretStore
        )

        self.configurationStore = configurationStore
        self.secretStore = secretStore
        self.claudeSettings = claudeSettings
        self.refreshCoordinator = ProviderRefreshCoordinator(
            configurationStore: configurationStore,
            secretStore: secretStore
        )
        self.onboardingDefaults = .standard
        self.appState = ProviderStateFactory().initialAppState(now: now)
        self.preferences = UserPreferences()
        self.popoverController = PopoverController()
        super.init()
    }

    func start() {
        let item = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)
        item.button?.target = self
        item.button?.action = #selector(handleStatusItemClick(_:))
        item.button?.sendAction(on: [.leftMouseUp, .rightMouseUp])
        item.button?.toolTip = "Pitwall provider pacing"
        statusItem = item

        applyRotationIfNeeded()
        updateStatusTitle()
        updatePopover()
        startRotationTimer()
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
        statusItem?.button?.title = formatter.format(appState: appState, preferences: preferences)
    }

    private func updatePopover() {
        popoverController.update(
            appState: appState,
            preferences: preferences,
            onRefresh: { [weak self] in self?.refreshNow() },
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

    private func loadConfiguration(showOnboardingIfNeeded: Bool = true) {
        Task {
            let snapshot = await configurationStore.load()
            let accounts = (try? await claudeSettings.setupStates()) ?? []
            applyConfiguration(snapshot: snapshot, claudeAccounts: accounts)

            if showOnboardingIfNeeded,
               !onboardingDefaults.bool(forKey: Self.onboardingCompletedKey) {
                presentOnboarding(snapshot: snapshot, claudeAccounts: accounts)
            }
        }
    }

    private func presentSettings() {
        Task {
            let snapshot = await configurationStore.load()
            let accounts = (try? await claudeSettings.setupStates()) ?? []
            popoverController.showSettings(
                snapshot: snapshot,
                claudeAccounts: accounts,
                onSaveConfiguration: { [weak self] snapshot in
                    await self?.saveConfiguration(snapshot) ?? "Settings controller is unavailable."
                },
                onSaveClaudeCredentials: { [weak self] input in
                    await self?.saveClaudeCredentials(input) ?? "Settings controller is unavailable."
                },
                onDeleteClaudeCredentials: { [weak self] accountId in
                    await self?.deleteClaudeCredentials(accountId: accountId) ?? "Settings controller is unavailable."
                },
                onTestClaudeConnection: { [weak self] accountId in
                    await self?.testClaudeConnection(accountId: accountId) ?? "Settings controller is unavailable."
                },
                onRefresh: { [weak self] in
                    self?.refreshNow()
                }
            )
        }
    }

    private func presentOnboarding(
        snapshot: ProviderConfigurationSnapshot,
        claudeAccounts: [ClaudeAccountSetupState]
    ) {
        popoverController.showOnboarding(
            snapshot: snapshot,
            claudeAccounts: claudeAccounts,
            onSaveConfiguration: { [weak self] snapshot in
                await self?.saveConfiguration(snapshot) ?? "Onboarding controller is unavailable."
            },
            onSaveClaudeCredentials: { [weak self] input in
                await self?.saveClaudeCredentials(input) ?? "Onboarding controller is unavailable."
            },
            onTestClaudeConnection: { [weak self] accountId in
                await self?.testClaudeConnection(accountId: accountId) ?? "Onboarding controller is unavailable."
            },
            onFinish: { [weak self] in
                self?.onboardingDefaults.set(true, forKey: Self.onboardingCompletedKey)
                self?.popoverController.closeOnboarding()
                self?.loadConfiguration(showOnboardingIfNeeded: false)
            }
        )
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

    private func testClaudeConnection(accountId: String?) async -> String {
        let claudeState = await refreshCoordinator.testClaudeConnection(accountId: accountId)
        replaceProviderState(claudeState)
        updatePopover()
        updateStatusTitle()

        switch claudeState.status {
        case .configured:
            return "Claude connection succeeded."
        case .expired:
            return "Claude auth expired or invalid. Replace the saved credentials."
        case .stale, .degraded:
            return "Claude connection could not be verified; showing stale or degraded state."
        case .missingConfiguration:
            return "Claude credentials are missing."
        }
    }

    private func applyRefreshOutcome(_ outcome: ProviderRefreshOutcome) {
        appState = outcome.appState
        applyRotationIfNeeded(force: true)
        updatePopover()
        updateStatusTitle()
    }

    private func applyConfiguration(
        snapshot: ProviderConfigurationSnapshot,
        claudeAccounts: [ClaudeAccountSetupState]
    ) {
        preferences = snapshot.userPreferences
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

    private func replaceProviderState(_ provider: ProviderState) {
        appState.providers.removeAll { $0.providerId == provider.providerId }
        appState.providers.append(provider)
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

        for provider in appState.orderedProviders {
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
