import AppKit
import PitwallAppSupport
import Sparkle

final class AppDelegate: NSObject, NSApplicationDelegate {
    private var menuBarController: MenuBarController?
    private var updaterController: SPUStandardUpdaterController?
    private let packagingVersionProvider: PackagingVersionProvider
    private(set) var packagingVersion: PackagingVersion?

    init(packagingVersionProvider: PackagingVersionProvider = BundlePackagingVersionProvider()) {
        self.packagingVersionProvider = packagingVersionProvider
        super.init()
    }

    func applicationDidFinishLaunching(_ notification: Notification) {
        NSApp.setActivationPolicy(.accessory)
        packagingVersion = packagingVersionProvider.current()
        let updaterController = Self.makeUpdaterControllerIfConfigured()
        self.updaterController = updaterController
        let controller = MenuBarController(updater: updaterController?.updater)
        controller.start()
        menuBarController = controller
    }

    func applicationWillTerminate(_ notification: Notification) {
        menuBarController?.stop()
        menuBarController = nil
    }

    private static func makeUpdaterControllerIfConfigured() -> SPUStandardUpdaterController? {
        guard
            let feedURLString = Bundle.main.object(forInfoDictionaryKey: "SUFeedURL") as? String,
            !feedURLString.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
        else {
            return nil
        }

        return SPUStandardUpdaterController(
            startingUpdater: true,
            updaterDelegate: nil,
            userDriverDelegate: nil
        )
    }
}
