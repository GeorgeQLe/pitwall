import AppKit
import PitwallAppSupport
import PitwallCore
import SwiftUI

final class PopoverController {
    private let popover: NSPopover
    private var onboardingWindowController: NSWindowController?
    private var settingsWindowController: NSWindowController?

    init() {
        self.popover = NSPopover()
        popover.behavior = .transient
        popover.animates = true
    }

    func update(
        appState: AppProviderState,
        preferences: UserPreferences,
        onRefresh: @escaping () -> Void,
        onOpenSettings: @escaping () -> Void,
        onAddAccount: @escaping () -> Void,
        onSelectProvider: @escaping (ProviderID) -> Void
    ) {
        popover.contentSize = NSSize(width: 430, height: 620)
        popover.contentViewController = NSHostingController(
            rootView: PopoverContentView(
                appState: appState,
                preferences: preferences,
                onRefresh: onRefresh,
                onOpenSettings: onOpenSettings,
                onAddAccount: onAddAccount,
                onSelectProvider: onSelectProvider
            )
        )
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

    func showSettings(
        snapshot: ProviderConfigurationSnapshot,
        claudeAccounts: [ClaudeAccountSetupState],
        onSaveConfiguration: @escaping (ProviderConfigurationSnapshot) async -> String?,
        onSaveClaudeCredentials: @escaping (ClaudeCredentialInput) async -> String?,
        onDeleteClaudeCredentials: @escaping (String) async -> String?,
        onTestClaudeConnection: @escaping (String?) async -> String,
        onRefresh: @escaping () -> Void
    ) {
        let view = SettingsView(
            snapshot: snapshot,
            claudeAccounts: claudeAccounts,
            onSaveConfiguration: onSaveConfiguration,
            onSaveClaudeCredentials: onSaveClaudeCredentials,
            onDeleteClaudeCredentials: onDeleteClaudeCredentials,
            onTestClaudeConnection: onTestClaudeConnection,
            onRefresh: onRefresh
        )

        settingsWindowController = showWindow(
            existingController: settingsWindowController,
            title: "Pitwall Settings",
            contentSize: NSSize(width: 520, height: 640),
            rootView: view
        )
    }

    func showOnboarding(
        snapshot: ProviderConfigurationSnapshot,
        claudeAccounts: [ClaudeAccountSetupState],
        onSaveConfiguration: @escaping (ProviderConfigurationSnapshot) async -> String?,
        onSaveClaudeCredentials: @escaping (ClaudeCredentialInput) async -> String?,
        onTestClaudeConnection: @escaping (String?) async -> String,
        onFinish: @escaping () -> Void
    ) {
        let view = OnboardingView(
            snapshot: snapshot,
            claudeAccounts: claudeAccounts,
            onSaveConfiguration: onSaveConfiguration,
            onSaveClaudeCredentials: onSaveClaudeCredentials,
            onTestClaudeConnection: onTestClaudeConnection,
            onFinish: onFinish
        )

        onboardingWindowController = showWindow(
            existingController: onboardingWindowController,
            title: "Set Up Pitwall",
            contentSize: NSSize(width: 540, height: 660),
            rootView: view
        )
    }

    func closeOnboarding() {
        onboardingWindowController?.close()
        onboardingWindowController = nil
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
