import AppKit
import Foundation
import PitwallAppSupport
import PitwallCore

final class MenuBarController: NSObject {
    private let formatter = MenuBarStatusFormatter()
    private let rotationController = ProviderRotationController()
    private let popoverController: PopoverController
    private var statusItem: NSStatusItem?
    private var rotationTimer: Timer?
    private var appState: AppProviderState
    private var preferences: UserPreferences

    override init() {
        let now = Date()
        self.appState = Self.makeInitialAppState(now: now)
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
        let now = Date()
        appState.providers = appState.providers.map { provider in
            var updated = provider
            updated.lastUpdatedAt = now
            return updated
        }
        updatePopover()
        updateStatusTitle()
    }

    @objc private func openSettings() {
        NSApp.activate(ignoringOtherApps: true)
    }

    @objc private func addAccount() {
        NSApp.activate(ignoringOtherApps: true)
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
            self?.tickRotation()
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

    private static func makeInitialAppState(now: Date) -> AppProviderState {
        let resetWindow = ResetWindow(
            startsAt: now.addingTimeInterval(-4 * 60 * 60),
            resetsAt: now.addingTimeInterval(41 * 60)
        )

        let claudePacing = PacingState(
            weeklyUtilizationPercent: 82,
            remainingWindowDuration: 41 * 60,
            dailyBudget: DailyBudget(
                remainingUtilizationPercent: 18,
                daysRemaining: 0.7,
                dailyBudgetPercent: 25.7,
                todayUsage: TodayUsage(status: .exact, utilizationDeltaPercent: 12)
            ),
            todayUsage: TodayUsage(status: .exact, utilizationDeltaPercent: 12),
            weeklyPace: PaceEvaluation(
                label: .warning,
                action: .conserve,
                paceRatio: 1.24,
                expectedUtilizationPercent: 66,
                remainingWindowDuration: 41 * 60
            )
        )

        let providers = [
            ProviderState(
                providerId: .claude,
                displayName: "Claude",
                status: .configured,
                confidence: .exact,
                headline: "Conserve until reset",
                primaryValue: "82% used",
                secondaryValue: "25.7% daily budget",
                resetWindow: resetWindow,
                lastUpdatedAt: now.addingTimeInterval(-4 * 60),
                pacingState: claudePacing,
                confidenceExplanation: "Usage comes from provider-supplied account data. No saved credential value is displayed.",
                actions: [
                    ProviderAction(kind: .refresh, title: "Refresh"),
                    ProviderAction(kind: .openSettings, title: "Settings")
                ],
                payloads: [
                    ProviderSpecificPayload(
                        source: "usageRows",
                        values: [
                            "Weekly": "82|41m|warning",
                            "Today": "12|41m|exact"
                        ]
                    )
                ]
            ),
            ProviderState(
                providerId: .codex,
                displayName: "Codex",
                status: .configured,
                confidence: .highConfidence,
                headline: "Available from local signals",
                primaryValue: "High confidence",
                secondaryValue: "Passive metadata only",
                resetWindow: ResetWindow(resetsAt: now.addingTimeInterval(5 * 60 * 60)),
                lastUpdatedAt: now.addingTimeInterval(-22 * 60),
                confidenceExplanation: "Detected from sanitized local metadata. Prompt text, token values, stdout, and source content are not shown.",
                actions: [
                    ProviderAction(kind: .refresh, title: "Scan"),
                    ProviderAction(kind: .openSettings, title: "Configure")
                ]
            ),
            ProviderState(
                providerId: .gemini,
                displayName: "Gemini",
                status: .missingConfiguration,
                confidence: .observedOnly,
                headline: "Ready to configure",
                primaryValue: "No account selected",
                secondaryValue: "Visible as a configurable provider",
                lastUpdatedAt: nil,
                confidenceExplanation: "Gemini remains visible even before setup so it can be enabled later.",
                actions: [
                    ProviderAction(kind: .configure, title: "Configure"),
                    ProviderAction(kind: .openSettings, title: "Settings")
                ]
            )
        ]

        return AppProviderState(
            providers: providers,
            selectedProviderId: .claude
        )
    }
}
