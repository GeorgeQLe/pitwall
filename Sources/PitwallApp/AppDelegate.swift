import AppKit
import PitwallAppSupport

final class AppDelegate: NSObject, NSApplicationDelegate {
    private var menuBarController: MenuBarController?
    private let packagingVersionProvider: PackagingVersionProvider
    private(set) var packagingVersion: PackagingVersion?

    init(packagingVersionProvider: PackagingVersionProvider = BundlePackagingVersionProvider()) {
        self.packagingVersionProvider = packagingVersionProvider
        super.init()
    }

    func applicationDidFinishLaunching(_ notification: Notification) {
        NSApp.setActivationPolicy(.accessory)
        packagingVersion = packagingVersionProvider.current()
        let controller = MenuBarController()
        controller.start()
        menuBarController = controller
    }

    func applicationWillTerminate(_ notification: Notification) {
        menuBarController?.stop()
        menuBarController = nil
    }
}
