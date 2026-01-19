//
//  ContentView.swift
//  ink
//
//  Created by agentwaj on 1/17/26.
//

import SwiftUI
import AppKit
import Carbon
import Combine

struct DrawingStroke {
    let points: [CGPoint]
    let createdAt: Date
    var opacity: Double = 1.0
    
    init(points: [CGPoint], createdAt: Date) {
        self.points = points
        self.createdAt = createdAt
    }
}

class DrawingModel: ObservableObject {
    @Published var strokes: [DrawingStroke] = []
    private var currentStroke: [CGPoint] = []
    
    func startStroke(at point: CGPoint) {
        currentStroke = [point]
    }
    
    func addPoint(_ point: CGPoint) {
        currentStroke.append(point)
    }
    
    func endStroke() {
        if !currentStroke.isEmpty {
            let stroke = DrawingStroke(points: currentStroke, createdAt: Date())
            strokes.append(stroke)
            currentStroke = []
        }
    }
    
    func updateStrokes(at time: Date) {
        // Defer the updates to avoid "Publishing changes from within view updates" warning
        DispatchQueue.main.async {
            for i in self.strokes.indices.reversed() {
                let age = time.timeIntervalSince(self.strokes[i].createdAt)
                if age >= 3.0 {
                    self.strokes.remove(at: i)
                } else if age > 2.0 {
                    let fadeProgress = (age - 2.0) / 1.0
                    let newOpacity = max(0, 1.0 - fadeProgress)
                    self.strokes[i].opacity = newOpacity
                }
            }
        }
    }
    
    func getCurrentStroke() -> [CGPoint] {
        return currentStroke
    }
}

class WindowController: ObservableObject {
    var ignoreMouseEventsCallback: ((Bool) -> Void)?
    private var previousActiveApp: NSRunningApplication?
    
    func setIgnoreMouseEvents(_ ignore: Bool) {
        if !ignore {
            // Capture the currently active app before we start capturing mouse events
            previousActiveApp = NSWorkspace.shared.frontmostApplication
        }
        
        ignoreMouseEventsCallback?(ignore)
        
        if !ignore {
            // Immediately restore focus to the previously active app when we start capturing
            DispatchQueue.main.async {
                self.previousActiveApp?.activate()
            }
        } else if previousActiveApp != nil {
            // Also restore focus when we stop capturing
            DispatchQueue.main.async {
                self.previousActiveApp?.activate()
            }
        }
    }
}

struct DrawingCanvas: View {
    @StateObject private var drawingModel = DrawingModel()
    @ObservedObject private var windowController: WindowController
    @State private var isOptionPressed = false
    @State private var isDrawing = false
    @State private var cursorPosition = CGPoint.zero
    
    init(windowController: WindowController) {
        self.windowController = windowController
    }
    
    var body: some View {
        ZStack {
            TimelineView(.periodic(from: .now, by: 0.016)) { context in
                Canvas { canvasContext, size in
                    let currentTime = context.date
                    drawingModel.updateStrokes(at: currentTime)
                    
                    for stroke in drawingModel.strokes {
                        if stroke.points.count > 1 {
                            var path = Path()
                            path.move(to: stroke.points[0])
                            for i in 1..<stroke.points.count {
                                path.addLine(to: stroke.points[i])
                            }
                            canvasContext.stroke(path, with: .color(.red.opacity(stroke.opacity)), lineWidth: 3)
                        }
                    }
                    
                    let currentStroke = drawingModel.getCurrentStroke()
                    if currentStroke.count > 1 {
                        var path = Path()
                        path.move(to: currentStroke[0])
                        for i in 1..<currentStroke.count {
                            path.addLine(to: currentStroke[i])
                        }
                        canvasContext.stroke(path, with: .color(.red), lineWidth: 3)
                    }
                    
                    // Ultra-simple glow at cursor position  
                    if isOptionPressed {
                        let centerX = cursorPosition.x
                        let centerY = cursorPosition.y
                        let time = currentTime.timeIntervalSinceReferenceDate
                        
                        // Just three simple circles for performance
                        let pulse = 1.0 + 0.2 * sin(time * 4)
                        
                        // Outer glow
                        let outerRadius = 20.0 * pulse
                        let outerRect = CGRect(x: centerX - outerRadius, y: centerY - outerRadius, width: outerRadius * 2, height: outerRadius * 2)
                        canvasContext.fill(Circle().path(in: outerRect), with: .color(.blue.opacity(0.1)))
                        
                        // Middle glow  
                        let middleRadius = 12.0 * pulse
                        let middleRect = CGRect(x: centerX - middleRadius, y: centerY - middleRadius, width: middleRadius * 2, height: middleRadius * 2)
                        canvasContext.fill(Circle().path(in: middleRect), with: .color(.blue.opacity(0.2)))
                        
                        // Inner core
                        let innerRadius = 6.0 * pulse
                        let innerRect = CGRect(x: centerX - innerRadius, y: centerY - innerRadius, width: innerRadius * 2, height: innerRadius * 2)
                        canvasContext.fill(Circle().path(in: innerRect), with: .color(.cyan.opacity(0.4)))
                    }
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .contentShape(Rectangle())
            }
            .gesture(
                DragGesture(minimumDistance: 0, coordinateSpace: .local)
                    .onChanged { value in
                        cursorPosition = value.location
                        if isOptionPressed {
                            if !isDrawing {
                                drawingModel.startStroke(at: value.location)
                                isDrawing = true
                            } else {
                                drawingModel.addPoint(value.location)
                            }
                        }
                    }
                    .onEnded { _ in
                        if isDrawing {
                            drawingModel.endStroke()
                            isDrawing = false
                        }
                    }
            )
            .onContinuousHover { phase in
                switch phase {
                case .active(let location):
                    cursorPosition = location
                case .ended:
                    break
                }
            }
            
        }
        .onAppear {
            startKeyMonitoring()
        }
    }
    
    private func startKeyMonitoring() {
        NSEvent.addGlobalMonitorForEvents(matching: [.flagsChanged]) { event in
            let optionPressed = event.modifierFlags.contains(.option)
            if optionPressed != isOptionPressed {
                isOptionPressed = optionPressed
                windowController.setIgnoreMouseEvents(!optionPressed)
                if !optionPressed && isDrawing {
                    drawingModel.endStroke()
                    isDrawing = false
                }
            }
        }
        
        NSEvent.addLocalMonitorForEvents(matching: [.flagsChanged]) { event in
            let optionPressed = event.modifierFlags.contains(.option)
            if optionPressed != isOptionPressed {
                isOptionPressed = optionPressed
                windowController.setIgnoreMouseEvents(!optionPressed)
                if !optionPressed && isDrawing {
                    drawingModel.endStroke()
                    isDrawing = false
                }
            }
            return event
        }
    }
}

class OverlayWindow: NSWindow {
    private let mouseController = WindowController()
    
    override init(contentRect: NSRect, styleMask style: NSWindow.StyleMask, backing backingStoreType: NSWindow.BackingStoreType, defer flag: Bool) {
        super.init(contentRect: NSScreen.main?.frame ?? NSRect.zero, styleMask: [.borderless], backing: .buffered, defer: false)
        
        self.level = NSWindow.Level(rawValue: Int(CGWindowLevelForKey(.maximumWindow)))
        self.backgroundColor = NSColor.clear
        self.isOpaque = false
        self.ignoresMouseEvents = true // Start with mouse events ignored
        self.collectionBehavior = [.canJoinAllSpaces, .stationary, .ignoresCycle, .fullScreenAuxiliary]
        
        // Set up callback to control mouse event handling
        mouseController.ignoreMouseEventsCallback = { [weak self] ignore in
            DispatchQueue.main.async {
                self?.ignoresMouseEvents = ignore
            }
        }
        
        let drawingCanvas = DrawingCanvas(windowController: mouseController)
        let contentView = NSHostingView(rootView: drawingCanvas)
        contentView.frame = self.frame
        self.contentView = contentView
    }
    
    // Prevent this window from ever becoming the key window
    override var canBecomeKey: Bool {
        return false
    }
    
    // Prevent this window from ever becoming the main window
    override var canBecomeMain: Bool {
        return false
    }
    
    // Override to ensure we never steal focus
    override func makeKeyAndOrderFront(_ sender: Any?) {
        self.orderFront(sender)
    }
}

struct ContentView: View {
    var body: some View {
        Text("Ink Drawing App")
            .padding()
    }
}
