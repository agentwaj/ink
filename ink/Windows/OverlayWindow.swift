import AppKit
import SwiftUI

class OverlayWindow: NSWindow {
    private let mouseController = WindowController()

    convenience init() {
        self.init(
            contentRect: NSScreen.main?.frame ?? .zero,
            styleMask: [.borderless],
            backing: .buffered,
            defer: false
        )
    }

    override init(contentRect: NSRect, styleMask style: NSWindow.StyleMask, backing backingStoreType: NSWindow.BackingStoreType, defer flag: Bool) {
        super.init(contentRect: contentRect, styleMask: style, backing: backingStoreType, defer: flag)
        setupWindow()
        setupContent()
    }

    private func setupWindow() {
        level = NSWindow.Level(rawValue: Int(CGWindowLevelForKey(.maximumWindow)))
        backgroundColor = .clear
        isOpaque = false
        ignoresMouseEvents = true
        collectionBehavior = [.canJoinAllSpaces, .stationary, .ignoresCycle, .fullScreenAuxiliary]

        mouseController.ignoreMouseEventsCallback = { [weak self] ignore in
            DispatchQueue.main.async {
                self?.ignoresMouseEvents = ignore
            }
        }
    }

    private func setupContent() {
        let drawingCanvas = DrawingCanvas(windowController: mouseController)
        let hostingView = NSHostingView(rootView: drawingCanvas)
        hostingView.frame = frame
        contentView = hostingView
    }

    override var canBecomeKey: Bool { false }
    override var canBecomeMain: Bool { false }

    override func makeKeyAndOrderFront(_ sender: Any?) {
        orderFront(sender)
    }
}
