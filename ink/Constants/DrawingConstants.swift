import SwiftUI

// MARK: - Constants

enum DrawingConstants {
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

// MARK: - Extensions

extension CGRect {
    init(center: CGPoint, size: CGSize) {
        self.init(
            x: center.x - size.width / 2,
            y: center.y - size.height / 2,
            width: size.width,
            height: size.height
        )
    }
}
