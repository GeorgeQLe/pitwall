import AppKit
import PitwallAppSupport
import PitwallCore
import SwiftUI

final class PopoverController {
    private let popover: NSPopover

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
}
