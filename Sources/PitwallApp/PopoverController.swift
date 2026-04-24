import AppKit
import PitwallAppSupport
import PitwallCore
import Sparkle
import SwiftUI

final class PopoverController: NSObject, NSPopoverDelegate, NSWindowDelegate {
    private static let normalContentSize = NSSize(width: 430, height: 620)
    private static let onboardingPanelSize = NSSize(width: 520, height: 580)

    private let popover: NSPopover
    private var hostingController: NSHostingController<PopoverContentView>?
    private var settingsWindowController: NSWindowController?
    private var onboardingWindowController: NSWindowController?

    override init() {
        self.popover = NSPopover()
        super.init()
        popover.behavior = .transient
        popover.animates = true
        popover.contentSize = Self.normalContentSize
        popover.delegate = self
    }

    func popoverShouldDetach(_ popover: NSPopover) -> Bool { false }

    var onboardingPanelActive: Bool {
        onboardingWindowController?.window?.isVisible == true
    }

    func update(
        appState: AppProviderState,
        preferences: UserPreferences,
        historySnapshots: [ProviderHistorySnapshot],
        gitHubHeatmap: GitHubHeatmap?,
        gitHubHeatmapSettings: GitHubHeatmapSettings,
        onRefresh: @escaping () -> Void,
        onRefreshGitHubHeatmap: @escaping () -> Void,
        onOpenSettings: @escaping () -> Void,
        onAddAccount: @escaping () -> Void,
        onSelectProvider: @escaping (ProviderID) -> Void
    ) {
        let rootView = PopoverContentView(
            appState: appState,
            preferences: preferences,
            historySnapshots: historySnapshots,
            gitHubHeatmap: gitHubHeatmap,
            gitHubHeatmapSettings: gitHubHeatmapSettings,
            onRefresh: onRefresh,
            onRefreshGitHubHeatmap: onRefreshGitHubHeatmap,
            onOpenSettings: onOpenSettings,
            onAddAccount: onAddAccount,
            onSelectProvider: onSelectProvider
        )

        if let hostingController {
            hostingController.rootView = rootView
        } else {
            let controller = NSHostingController(rootView: rootView)
            controller.preferredContentSize = Self.normalContentSize
            hostingController = controller
            popover.contentViewController = controller
        }
    }

    func toggle(relativeTo positioningRect: NSRect, of positioningView: NSView) {
        if popover.isShown {
            popover.performClose(nil)
            return
        }

        popover.show(
            relativeTo: positioningRect,
            of: positioningView,
            preferredEdge: .minY
        )
    }

    func presentOnboardingPanel(
        anchoredTo statusButton: NSStatusBarButton,
        snapshot: ProviderConfigurationSnapshot,
        claudeAccounts: [ClaudeAccountSetupState],
        onSaveConfiguration: @escaping (ProviderConfigurationSnapshot) async -> String?,
        onSaveClaudeCredentials: @escaping (ClaudeCredentialInput) async -> String?,
        onTestClaudeConnection: @escaping (String?) async -> String,
        onFinish: @escaping () -> Void
    ) {
        let wizard = OnboardingWizardView(
            snapshot: snapshot,
            claudeAccounts: claudeAccounts,
            onSaveConfiguration: onSaveConfiguration,
            onSaveClaudeCredentials: onSaveClaudeCredentials,
            onTestClaudeConnection: onTestClaudeConnection,
            onFinish: onFinish
        )

        let hostingController = NSHostingController(rootView: wizard)
        hostingController.preferredContentSize = Self.onboardingPanelSize

        let panel: NSPanel
        if let existing = onboardingWindowController?.window as? NSPanel {
            panel = existing
            panel.contentViewController = hostingController
        } else {
            panel = NSPanel(
                contentRect: NSRect(origin: .zero, size: Self.onboardingPanelSize),
                styleMask: [.titled, .closable, .nonactivatingPanel],
                backing: .buffered,
                defer: false
            )
            panel.isReleasedWhenClosed = false
            panel.title = "Set Up Pitwall"
            panel.isFloatingPanel = true
            panel.becomesKeyOnlyIfNeeded = true
            panel.hidesOnDeactivate = false
            panel.level = .floating
            panel.isMovableByWindowBackground = true
            panel.delegate = self
            panel.contentViewController = hostingController
            onboardingWindowController = NSWindowController(window: panel)
        }

        positionOnboardingPanel(panel, under: statusButton)
        panel.makeKeyAndOrderFront(nil)
    }

    func dismissOnboardingPanel() {
        onboardingWindowController?.window?.close()
        onboardingWindowController = nil
    }

    func windowWillClose(_ notification: Notification) {
        guard
            let window = notification.object as? NSWindow,
            window === onboardingWindowController?.window
        else { return }
        onboardingWindowController = nil
    }

    private func positionOnboardingPanel(_ panel: NSPanel, under statusButton: NSStatusBarButton) {
        guard let buttonWindow = statusButton.window else { return }
        let buttonFrameInWindow = statusButton.convert(statusButton.bounds, to: nil)
        let buttonScreenFrame = buttonWindow.convertToScreen(buttonFrameInWindow)

        let panelSize = Self.onboardingPanelSize
        var origin = NSPoint(
            x: buttonScreenFrame.midX - panelSize.width / 2,
            y: buttonScreenFrame.minY - panelSize.height - 6
        )

        let screen = buttonWindow.screen ?? NSScreen.main
        if let visibleFrame = screen?.visibleFrame {
            let minX = visibleFrame.minX
            let maxX = visibleFrame.maxX - panelSize.width
            if maxX >= minX {
                origin.x = min(max(origin.x, minX), maxX)
            }
            let minY = visibleFrame.minY
            if origin.y < minY {
                origin.y = minY
            }
        }

        panel.setFrameOrigin(origin)
    }

    func showSettings(
        snapshot: ProviderConfigurationSnapshot,
        phase4Settings: Phase4Settings,
        claudeAccounts: [ClaudeAccountSetupState],
        onSaveConfiguration: @escaping (ProviderConfigurationSnapshot) async -> String?,
        onSavePhase4Settings: @escaping (Phase4Settings) async -> String?,
        onSaveGitHubToken: @escaping (String, String) async -> GitHubHeatmapTokenStatus?,
        onExportDiagnostics: @escaping () async -> String,
        onSaveClaudeCredentials: @escaping (ClaudeCredentialInput) async -> String?,
        onDeleteClaudeCredentials: @escaping (String) async -> String?,
        onTestClaudeConnection: @escaping (String?) async -> String,
        onRefresh: @escaping () -> Void,
        loginItemService: LoginItemService? = nil,
        updater: SPUUpdater? = nil
    ) {
        let view = SettingsView(
            snapshot: snapshot,
            phase4Settings: phase4Settings,
            claudeAccounts: claudeAccounts,
            onSaveConfiguration: onSaveConfiguration,
            onSavePhase4Settings: onSavePhase4Settings,
            onSaveGitHubToken: onSaveGitHubToken,
            onExportDiagnostics: onExportDiagnostics,
            onSaveClaudeCredentials: onSaveClaudeCredentials,
            onDeleteClaudeCredentials: onDeleteClaudeCredentials,
            onTestClaudeConnection: onTestClaudeConnection,
            onRefresh: onRefresh,
            loginItemService: loginItemService,
            updater: updater
        )

        settingsWindowController = showWindow(
            existingController: settingsWindowController,
            title: "Pitwall Settings",
            contentSize: NSSize(width: 520, height: 640),
            rootView: view
        )
    }

    private func showWindow<Content: View>(
        existingController: NSWindowController?,
        title: String,
        contentSize: NSSize,
        rootView: Content
    ) -> NSWindowController {
        if let existingController {
            existingController.window?.makeKeyAndOrderFront(nil)
            NSApp.activate(ignoringOtherApps: true)
            return existingController
        }

        let window = NSWindow(
            contentRect: NSRect(origin: .zero, size: contentSize),
            styleMask: [.titled, .closable, .miniaturizable],
            backing: .buffered,
            defer: false
        )
        window.title = title
        window.contentViewController = NSHostingController(rootView: rootView)
        window.center()

        let controller = NSWindowController(window: window)
        controller.showWindow(nil)
        NSApp.activate(ignoringOtherApps: true)
        return controller
    }
}
