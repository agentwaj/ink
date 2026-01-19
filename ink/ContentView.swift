//
//  ContentView.swift
//  ink
//
//  Created by agentwaj on 1/17/26.
//

import SwiftUI
import AppKit
import Combine

// MARK: - Extensions
private extension CGRect {
    init(center: CGPoint, size: CGSize) {
        self.init(
            x: center.x - size.width / 2,
            y: center.y - size.height / 2,
            width: size.width,
            height: size.height
        )
    }
}

// MARK: - Constants
private enum DrawingConstants {
    static let strokeWidth: CGFloat = 3
    static let fadeStartTime: TimeInterval = 2.0
    static let totalFadeTime: TimeInterval = 3.0
    static let frameDuration: TimeInterval = 0.016 // 60fps
    
    static let glowPulseSpeed: Double = 4
    static let glowPulseAmount: Double = 0.2
    static let glowOuterRadius: Double = 20.0
    static let glowMiddleRadius: Double = 12.0
    static let glowInnerRadius: Double = 6.0
    
    static let strokeStyle = StrokeStyle(
        lineWidth: strokeWidth,
        lineCap: .round,
        lineJoin: .round
    )
}

struct DrawingStroke {
    let points: [CGPoint]
    let createdAt: Date
    var opacity: Double = 1.0
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
            let stroke = DrawingStroke(points: currentStroke, createdAt: Date(), opacity: 1.0)
            strokes.append(stroke)
            currentStroke = []
        }
    }
    
    func updateStrokes(at time: Date) {
        // Defer the updates to avoid "Publishing changes from within view updates" warning
        DispatchQueue.main.async {
            for i in self.strokes.indices.reversed() {
                let age = time.timeIntervalSince(self.strokes[i].createdAt)
                if age >= DrawingConstants.totalFadeTime {
                    self.strokes.remove(at: i)
                } else if age > DrawingConstants.fadeStartTime {
                    let fadeProgress = (age - DrawingConstants.fadeStartTime) / (DrawingConstants.totalFadeTime - DrawingConstants.fadeStartTime)
                    self.strokes[i].opacity = max(0, 1.0 - fadeProgress)
                }
            }
        }
    }
    
    var currentStrokePoints: [CGPoint] { currentStroke }
}

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
            TimelineView(.periodic(from: .now, by: DrawingConstants.frameDuration)) { context in
                Canvas { canvasContext, size in
                    let currentTime = context.date
                    drawingModel.updateStrokes(at: currentTime)
                    
                    // Render completed strokes
                    for stroke in drawingModel.strokes {
                        drawStroke(stroke.points, opacity: stroke.opacity, on: canvasContext)
                    }
                    
                    // Render current stroke
                    drawStroke(drawingModel.currentStrokePoints, opacity: 1.0, on: canvasContext)
                    
                    // Render glow effect
                    if isOptionPressed {
                        drawGlowEffect(at: cursorPosition, time: currentTime.timeIntervalSinceReferenceDate, on: canvasContext)
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
    
    private func drawStroke(_ points: [CGPoint], opacity: Double, on context: GraphicsContext) {
        guard points.count > 1 else { return }
        
        var path = Path()
        path.move(to: points[0])
        
        for point in points.dropFirst() {
            path.addLine(to: point)
        }
        
        context.stroke(path, with: .color(.white.opacity(opacity)), style: DrawingConstants.strokeStyle)
    }
    
    private func drawGlowEffect(at position: CGPoint, time: TimeInterval, on context: GraphicsContext) {
        let pulseValue = sin(time * DrawingConstants.glowPulseSpeed) * DrawingConstants.glowPulseAmount + 1.0
        
        drawGlowLayer(at: position, radius: DrawingConstants.glowOuterRadius, opacity: 0.1, pulse: pulseValue, on: context)
        drawGlowLayer(at: position, radius: DrawingConstants.glowMiddleRadius, opacity: 0.3, pulse: pulseValue, on: context)
        drawGlowLayer(at: position, radius: DrawingConstants.glowInnerRadius, opacity: 0.6, pulse: pulseValue, on: context)
    }
    
    private func drawGlowLayer(at position: CGPoint, radius: Double, opacity: Double, pulse: Double, on context: GraphicsContext) {
        let adjustedRadius = radius * pulse
        let gradient = Gradient(colors: [.white.opacity(opacity * pulse), .clear])
        let rect = CGRect(center: position, size: CGSize(width: adjustedRadius * 2, height: adjustedRadius * 2))
        
        context.fill(
            Circle().path(in: rect),
            with: .radialGradient(gradient, center: position, startRadius: 0, endRadius: adjustedRadius)
        )
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

struct ContentView: View {
    var body: some View {
        Text("Ink Drawing App")
            .padding()
    }
}
