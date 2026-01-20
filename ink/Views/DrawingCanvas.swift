import AppKit
import SwiftUI

struct DrawingCanvas: View {
    @StateObject private var drawingModel = DrawingModel()
    @ObservedObject private var windowController: WindowController
    @State private var isModifierPressed = false
    @State private var isDrawing = false
    @State private var cursorPosition = CGPoint.zero

    init(windowController: WindowController) {
        self.windowController = windowController
    }

    var body: some View {
        ZStack {
            TimelineView(.periodic(from: .now, by: DrawingConstants.frameDuration)) { context in
                Canvas { canvasContext, _ in
                    let currentTime = context.date
                    drawingModel.updateStrokes(at: currentTime)

                    // Render completed strokes
                    for stroke in drawingModel.strokes {
                        drawStroke(stroke.points, opacity: stroke.opacity, on: canvasContext)
                    }

                    // Render current stroke
                    drawStroke(drawingModel.currentStrokePoints, opacity: 1.0, on: canvasContext)

                    // Render glow effect
                    if isModifierPressed {
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
                        if isModifierPressed {
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
                case let .active(location):
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

        context.stroke(path, with: .color(.green.opacity(opacity * 0.25)), style: DrawingConstants.strokeGlowStyle2)
        context.stroke(path, with: .color(.green.opacity(opacity * 0.5)), style: DrawingConstants.strokeGlowStyle1)
        context.stroke(path, with: .color(.green.opacity(opacity)), style: DrawingConstants.strokeStyle)
    }

    private func drawGlowEffect(at position: CGPoint, time: TimeInterval, on context: GraphicsContext) {
        let pulse = sin(time * DrawingConstants.glowPulseSpeed) * DrawingConstants.glowPulseAmount + 1.0
        for (radius, opacity) in [
            (DrawingConstants.glowOuterRadius, 0.1),
            (DrawingConstants.glowMiddleRadius, 0.3),
            (DrawingConstants.glowInnerRadius, 0.6),
        ] {
            let adjustedRadius = radius * pulse
            let gradient = Gradient(colors: [.white.opacity(opacity * pulse), .clear])
            let rect = CGRect(center: position, size: CGSize(width: adjustedRadius * 2, height: adjustedRadius * 2))

            context.fill(
                Circle().path(in: rect),
                with: .radialGradient(gradient, center: position, startRadius: 0, endRadius: adjustedRadius)
            )
        }
    }

    private func startKeyMonitoring() {
        NSEvent.addGlobalMonitorForEvents(matching: [.flagsChanged]) { event in
            let optionShiftPressed = event.modifierFlags.contains([.option, .shift])
            if optionShiftPressed != isModifierPressed {
                isModifierPressed = optionShiftPressed
                windowController.setIgnoreMouseEvents(!optionShiftPressed)
                if !optionShiftPressed, isDrawing {
                    drawingModel.endStroke()
                    isDrawing = false
                }
            }
        }

        NSEvent.addLocalMonitorForEvents(matching: [.flagsChanged]) { event in
            let optionShiftPressed = event.modifierFlags.contains([.option, .shift])
            if optionShiftPressed != isModifierPressed {
                isModifierPressed = optionShiftPressed
                windowController.setIgnoreMouseEvents(!optionShiftPressed)
                if !optionShiftPressed, isDrawing {
                    drawingModel.endStroke()
                    isDrawing = false
                }
            }
            return event
        }
    }
}
