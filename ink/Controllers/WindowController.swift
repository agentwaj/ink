import AppKit
import Combine

class WindowController: ObservableObject {
    var ignoreMouseEventsCallback: ((Bool) -> Void)?
    private var previousActiveApp: NSRunningApplication?

    func setIgnoreMouseEvents(_ ignore: Bool) {
        if !ignore {
            previousActiveApp = NSWorkspace.shared.frontmostApplication
        }

        ignoreMouseEventsCallback?(ignore)

        if let activeApp = previousActiveApp {
            DispatchQueue.main.async {
                activeApp.activate()
            }
        }
    }
}
