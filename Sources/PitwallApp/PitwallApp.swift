import AppKit
import Foundation
import PitwallAppSupport
#if canImport(ServiceManagement)
import ServiceManagement
#endif

private var retainedAppDelegate: AppDelegate?

@main
enum PitwallApp {
    static func main() {
        if CommandLine.arguments.contains("--unregister-login-item") {
            unregisterLoginItemAndExit()
        }

        let application = NSApplication.shared
        let delegate = AppDelegate()

        retainedAppDelegate = delegate
        application.delegate = delegate
        application.setActivationPolicy(.accessory)
        installMainMenu(on: application)
        application.run()
    }

    private static func installMainMenu(on application: NSApplication) {
        let mainMenu = NSMenu()
        let appMenuItem = NSMenuItem()
        let editMenuItem = NSMenuItem()

        mainMenu.addItem(appMenuItem)
        mainMenu.addItem(editMenuItem)

        let appMenu = NSMenu(title: "Pitwall")
        appMenu.addItem(
            NSMenuItem(
                title: "Quit Pitwall",
                action: #selector(NSApplication.terminate(_:)),
                keyEquivalent: "q"
            )
        )
        appMenuItem.submenu = appMenu

        let editMenu = NSMenu(title: "Edit")
        editMenu.addItem(NSMenuItem(title: "Undo", action: Selector(("undo:")), keyEquivalent: "z"))
        editMenu.addItem(NSMenuItem(title: "Redo", action: Selector(("redo:")), keyEquivalent: "Z"))
        editMenu.addItem(.separator())
        editMenu.addItem(NSMenuItem(title: "Cut", action: #selector(NSText.cut(_:)), keyEquivalent: "x"))
        editMenu.addItem(NSMenuItem(title: "Copy", action: #selector(NSText.copy(_:)), keyEquivalent: "c"))
        editMenu.addItem(NSMenuItem(title: "Paste", action: #selector(NSText.paste(_:)), keyEquivalent: "v"))
        editMenu.addItem(NSMenuItem(title: "Select All", action: #selector(NSText.selectAll(_:)), keyEquivalent: "a"))
        editMenuItem.submenu = editMenu

        application.mainMenu = mainMenu
    }

    private static func unregisterLoginItemAndExit() -> Never {
        #if canImport(ServiceManagement)
        if #available(macOS 13.0, *) {
            try? SMAppService.mainApp.unregister()
        }
        #endif
        exit(0)
    }
}
