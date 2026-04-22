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
        application.run()
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
