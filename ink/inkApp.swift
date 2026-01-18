//
//  inkApp.swift
//  ink
//
//  Created by agentwaj on 1/17/26.
//

import SwiftUI
import AppKit

class AppDelegate: NSObject, NSApplicationDelegate {
    var statusItem: NSStatusItem?
    var overlayWindow: OverlayWindow?
    
    func applicationDidFinishLaunching(_ notification: Notification) {
        setupStatusItem()
        setupOverlayWindow()
        
        // Hide dock icon since we only want menu bar presence
        NSApp.setActivationPolicy(.accessory)
    }
    
    private func setupStatusItem() {
        statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)
        
        if let button = statusItem?.button {
            button.image = NSImage(systemSymbolName: "pencil.circle", accessibilityDescription: "Ink Drawing")
            button.toolTip = "Ink - Hold Option key to draw"
        }
        
        let menu = NSMenu()
        menu.addItem(NSMenuItem(title: "Ink Drawing App", action: nil, keyEquivalent: ""))
        menu.addItem(NSMenuItem.separator())
        menu.addItem(NSMenuItem(title: "Instructions:", action: nil, keyEquivalent: ""))
        menu.addItem(NSMenuItem(title: "  • Hold Option (⌥) key and drag to draw", action: nil, keyEquivalent: ""))
        menu.addItem(NSMenuItem(title: "  • Strokes fade after 3 seconds", action: nil, keyEquivalent: ""))
        menu.addItem(NSMenuItem.separator())
        menu.addItem(NSMenuItem(title: "Quit", action: #selector(quitApp), keyEquivalent: "q"))
        
        statusItem?.menu = menu
    }
    
    private func setupOverlayWindow() {
        overlayWindow = OverlayWindow()
        overlayWindow?.makeKeyAndOrderFront(nil)
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
