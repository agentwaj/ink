import Combine
import SwiftUI

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
