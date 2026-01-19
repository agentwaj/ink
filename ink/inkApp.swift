import AppKit
import SwiftUI

class AppDelegate: NSObject, NSApplicationDelegate {
    var statusItem: NSStatusItem?
    var overlayWindow: OverlayWindow?

    func applicationDidFinishLaunching(_: Notification) {
        setupStatusItem()
        setupOverlayWindow()

        // Hide dock icon since we only want menu bar presence
        NSApp.setActivationPolicy(.accessory)
    }

    private func setupStatusItem() {
        statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)

        if let button = statusItem?.button {
            button.image = NSImage(systemSymbolName: "scribble.variable", accessibilityDescription: "Ink")
            button.toolTip = "Ink"
        }

        let menu = NSMenu()
        menu.addItem(NSMenuItem(title: "Ink", action: nil, keyEquivalent: ""))
        menu.addItem(NSMenuItem.separator())
        menu.addItem(NSMenuItem(title: "Instructions:", action: nil, keyEquivalent: ""))
        menu.addItem(NSMenuItem(title: "  • Hold Option + Shift (⌥⇧) and drag to draw", action: nil, keyEquivalent: ""))
        menu.addItem(NSMenuItem(title: "  • Strokes fade after 3 seconds", action: nil, keyEquivalent: ""))
        menu.addItem(NSMenuItem.separator())
        menu.addItem(NSMenuItem(title: "Quit", action: #selector(quitApp), keyEquivalent: ""))

        statusItem?.menu = menu
    }

    private func setupOverlayWindow() {
        overlayWindow = OverlayWindow()
        overlayWindow?.orderFront(nil)
    }

    @objc private func quitApp() {
        NSApplication.shared.terminate(self)
    }
}

@main
struct inkApp: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) var appDelegate

    var body: some Scene {
        Settings {
            EmptyView()
        }
    }
}
