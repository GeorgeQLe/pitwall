import AppKit
import PitwallAppSupport

private var retainedAppDelegate: AppDelegate?

@main
enum PitwallApp {
    static func main() {
        let application = NSApplication.shared
        let delegate = AppDelegate()

        retainedAppDelegate = delegate
        application.delegate = delegate
        application.setActivationPolicy(.accessory)
        application.run()
    }
}
